import assert from "node:assert/strict";
import test from "node:test";
import { isAuthorized } from "../src/auth.js";
import { activateIndex, handleHandbookAdminRequest, startIndexing, uploadChunks } from "../src/handbook-ingestion.js";

const sourceHash = "a".repeat(64);
const generationID = `v2-${sourceHash.slice(0, 12)}`;
const chunkIDs = ["chapter:section:block:abc"];
const run = { generationID, contentVersion: 2, sourceHash, chunkCount: 1, chunkIDs, status: "uploading" };

test("uses timing-safe bearer authentication", async () => {
  const accepted = await isAuthorized(new Request("https://example.com", { headers: { Authorization: "Bearer correct" } }), "correct");
  const rejected = await isAuthorized(new Request("https://example.com", { headers: { Authorization: "Bearer wrong" } }), "correct");
  assert.equal(accepted, true);
  assert.equal(rejected, false);
});

test("start is resumable, no-ops for the active hash, and rejects an unbumped version", async () => {
  const state = new MemoryKV();
  const env = { HANDBOOK_INDEX_STATE: state };
  const input = { contentVersion: 2, sourceHash, generationID, chunkCount: 1, chunkIDs };

  assert.equal((await startIndexing(input, env)).status, 200);
  assert.equal((await (await startIndexing(input, env)).json()).resumed, true);

  const changedHash = "b".repeat(64);
  const changed = { ...input, sourceHash: changedHash, generationID: `v2-${changedHash.slice(0, 12)}` };
  assert.equal((await startIndexing(changed, env)).status, 409);

  await state.put("handbook:index:active", JSON.stringify({ contentVersion: 2, sourceHash, generationID }));
  assert.equal((await (await startIndexing(input, env)).json()).noOp, true);
  assert.equal((await startIndexing(changed, env)).status, 409);
});

test("chunk uploads resume when a manifest chunk is already attached", async () => {
  const state = new MemoryKV({ [`handbook:index:run:${generationID}`]: run });
  const env = { OPENAI_API_KEY: "key", HANDBOOK_VECTOR_STORE_ID: "vs", HANDBOOK_INDEX_STATE: state };
  const chunk = {
    id: chunkIDs[0], contentVersion: 2, chapterID: "chapter", chapterTitle: "Chapter",
    sectionID: "section", sectionTitle: "Section", blockIDs: ["block"], text: "# Chapter\n\n## Section\n\nText"
  };
  const fetchImpl = async url => {
    assert.match(url, /vector_stores\/vs\/files/);
    return Response.json({ data: [{ id: "file", attributes: { source: "quizie-handbook", generation_id: generationID, chunk_id: chunk.id } }], has_more: false });
  };
  const response = await uploadChunks(generationID, { chunks: [chunk] }, env, fetchImpl);

  assert.deepEqual(await response.json(), { uploaded: 0, skipped: 1 });
  assert.deepEqual((await state.get(`handbook:index:run:${generationID}`, "json")).uploadedFileIDs, ["file"]);
});

test("activation waits for processing and then atomically records a verified generation", async () => {
  const state = new MemoryKV({ [`handbook:index:run:${generationID}`]: run });
  const env = { OPENAI_API_KEY: "key", HANDBOOK_VECTOR_STORE_ID: "vs", HANDBOOK_INDEX_STATE: state };
  const file = { id: "file", status: "in_progress", attributes: { source: "quizie-handbook", generation_id: generationID, chunk_id: chunkIDs[0] } };
  let completed = false;
  const fetchImpl = async (url, options = {}) => {
    if (url.includes("/search")) {
      const body = JSON.parse(options.body);
      assert.equal(body.filters.value, generationID);
      return Response.json({ data: [{ attributes: { chunk_id: chunkIDs[0] } }] });
    }
    if (url.includes("/vector_stores/vs/files")) return Response.json({ data: [{ ...file, status: completed ? "completed" : "in_progress" }], has_more: false });
    return Response.json({ deleted: true });
  };
  const input = { verificationQueries: [{ query: "Chapter section text", expectedChunkID: chunkIDs[0] }] };

  const pending = await activateIndex(generationID, input, env, fetchImpl);
  assert.equal(pending.status, 202);
  completed = true;
  const activated = await activateIndex(generationID, input, env, fetchImpl);
  assert.equal(activated.status, 200);
  assert.equal((await activated.json()).verifiedQueries, 1);
  assert.equal((await state.get("handbook:index:active", "json")).generationID, generationID);
  assert.deepEqual((await state.get("handbook:index:active", "json")).uploadedFileIDs, ["file"]);
});

test("activation rejects failed OpenAI files without changing the active generation", async () => {
  const previous = { generationID: "v1-previous", contentVersion: 1, sourceHash: "c".repeat(64) };
  const state = new MemoryKV({ [`handbook:index:run:${generationID}`]: run, "handbook:index:active": previous });
  const env = { OPENAI_API_KEY: "key", HANDBOOK_VECTOR_STORE_ID: "vs", HANDBOOK_INDEX_STATE: state };
  const fetchImpl = async url => {
    assert.match(url, /vector_stores\/vs\/files/);
    return Response.json({ data: [{ id: "file", status: "failed", attributes: { source: "quizie-handbook", generation_id: generationID, chunk_id: chunkIDs[0] } }], has_more: false });
  };
  const response = await activateIndex(generationID, { verificationQueries: [{ query: "Text", expectedChunkID: chunkIDs[0] }] }, env, fetchImpl);

  assert.equal(response.status, 409);
  assert.deepEqual(await state.get("handbook:index:active", "json"), previous);
});

test("admin routes reject missing or invalid ingest credentials", async () => {
  const configured = {
    OPENAI_API_KEY: "key", HANDBOOK_VECTOR_STORE_ID: "vs", HANDBOOK_INDEX_STATE: new MemoryKV(), HANDBOOK_INGEST_TOKEN: "secret"
  };
  const input = new Request("https://example.com/admin/handbook/index/start", { method: "POST", body: "{}" });
  assert.equal((await handleHandbookAdminRequest(input, configured)).status, 401);
  const unconfigured = await handleHandbookAdminRequest(new Request("https://example.com/admin/handbook/index/start", { method: "POST", body: "{}" }), {});
  assert.equal(unconfigured.status, 503);
});

class MemoryKV {
  constructor(values = {}) {
    this.values = new Map(Object.entries(values).map(([key, value]) => [key, JSON.stringify(value)]));
  }

  async get(key, type) {
    const value = this.values.get(key);
    if (value == null) return null;
    return type === "json" ? JSON.parse(value) : value;
  }

  async put(key, value) {
    this.values.set(key, value);
  }
}
