import { ACTIVE_INDEX_KEY, runKey, versionKey } from "./handbook-knowledge.js";
import { attachHandbookFile, deleteOpenAIFile, listHandbookFiles, searchHandbook, uploadHandbookFile } from "./openai-client.js";
import { isAuthorized } from "./auth.js";

const MAX_CHUNKS_PER_REQUEST = 10;
const MAX_CLEANUP_FILES = 500;
const PIPELINE_SOURCE = "quizie-handbook";

export async function handleHandbookAdminRequest(request, env, fetchImpl = globalThis.fetch) {
  const url = new URL(request.url);
  if (!url.pathname.startsWith("/admin/handbook/index")) return null;
  if (request.method !== "POST") return json({ error: "Not found." }, 404);
  if (!env.OPENAI_API_KEY || !env.HANDBOOK_VECTOR_STORE_ID || !env.HANDBOOK_INDEX_STATE || !env.HANDBOOK_INGEST_TOKEN) {
    return json({ error: "The handbook indexing service is not configured." }, 503);
  }
  if (!await isAuthorized(request, env.HANDBOOK_INGEST_TOKEN)) return json({ error: "Unauthorized." }, 401);

  let input;
  try {
    input = await request.json();
  } catch {
    return json({ error: "A valid JSON request is required." }, 400);
  }

  try {
    if (url.pathname === "/admin/handbook/index/start") return startIndexing(input, env);
    const match = url.pathname.match(/^\/admin\/handbook\/index\/([^/]+)\/(chunks|activate)$/);
    if (!match) return json({ error: "Not found." }, 404);
    const generationID = decodeURIComponent(match[1]);
    if (match[2] === "chunks") return uploadChunks(generationID, input, env, fetchImpl);
    return activateIndex(generationID, input, env, fetchImpl);
  } catch (error) {
    console.error(JSON.stringify({ event: "handbook_index_error", path: url.pathname, message: error.message }));
    return json({ error: error.message || "Handbook indexing failed." }, error.status || 500);
  }
}

export async function startIndexing(input, env) {
  const error = validateStartRequest(input);
  if (error) return json({ error }, 400);
  const active = await env.HANDBOOK_INDEX_STATE.get(ACTIVE_INDEX_KEY, "json");
  const knownVersion = await env.HANDBOOK_INDEX_STATE.get(versionKey(input.contentVersion), "json");
  if (active?.sourceHash === input.sourceHash) return json({ noOp: true, generationID: active.generationID });
  if ((active?.contentVersion === input.contentVersion && active.sourceHash !== input.sourceHash) || (knownVersion && knownVersion.sourceHash !== input.sourceHash)) {
    return json({ error: "handbook.json changed without incrementing content_version." }, 409);
  }

  const key = runKey(input.generationID);
  const existing = await env.HANDBOOK_INDEX_STATE.get(key, "json");
  if (existing) {
    const matches = existing.sourceHash === input.sourceHash && existing.chunkCount === input.chunkCount && arraysEqual(existing.chunkIDs, input.chunkIDs);
    if (!matches) return json({ error: "This generation ID is already associated with a different manifest." }, 409);
    await env.HANDBOOK_INDEX_STATE.put(versionKey(input.contentVersion), JSON.stringify({ sourceHash: input.sourceHash, generationID: input.generationID }));
    return json({ noOp: false, resumed: true, generationID: input.generationID });
  }

  await env.HANDBOOK_INDEX_STATE.put(key, JSON.stringify({
    generationID: input.generationID,
    contentVersion: input.contentVersion,
    sourceHash: input.sourceHash,
    chunkCount: input.chunkCount,
    chunkIDs: input.chunkIDs,
    uploadedFileIDs: [],
    status: "uploading",
    startedAt: new Date().toISOString()
  }));
  await env.HANDBOOK_INDEX_STATE.put(versionKey(input.contentVersion), JSON.stringify({ sourceHash: input.sourceHash, generationID: input.generationID }));
  return json({ noOp: false, resumed: false, generationID: input.generationID });
}

export async function uploadChunks(generationID, input, env, fetchImpl) {
  const run = await env.HANDBOOK_INDEX_STATE.get(runKey(generationID), "json");
  if (!run) return json({ error: "Indexing run not found." }, 404);
  const error = validateChunkBatch(input, run);
  if (error) return json({ error }, 400);

  const files = await listHandbookFiles(env, fetchImpl);
  const generationFiles = files.filter(file => file.attributes?.source === PIPELINE_SOURCE && file.attributes?.generation_id === generationID);
  const existingChunkIDs = new Set(generationFiles.map(file => file.attributes?.chunk_id));
  const missing = input.chunks.filter(chunk => !existingChunkIDs.has(chunk.id));
  const settled = await Promise.allSettled(missing.map(chunk => uploadChunk(chunk, generationID, env, fetchImpl)));
  const failures = settled.filter(result => result.status === "rejected");
  const uploadedFileIDs = [...new Set([
    ...(run.uploadedFileIDs || []),
    ...generationFiles.map(file => file.id),
    ...settled.filter(result => result.status === "fulfilled").map(result => result.value)
  ])];
  await env.HANDBOOK_INDEX_STATE.put(runKey(generationID), JSON.stringify({ ...run, uploadedFileIDs, updatedAt: new Date().toISOString() }));
  if (failures.length) {
    const firstError = failures[0].reason?.message || "OpenAI could not index a handbook chunk.";
    return json({ error: firstError, uploaded: settled.length - failures.length, skipped: input.chunks.length - missing.length }, 502);
  }
  return json({ uploaded: missing.length, skipped: input.chunks.length - missing.length });
}

export async function activateIndex(generationID, input, env, fetchImpl) {
  const run = await env.HANDBOOK_INDEX_STATE.get(runKey(generationID), "json");
  if (!run) return json({ error: "Indexing run not found." }, 404);
  const verificationError = validateVerificationQueries(input?.verificationQueries, run);
  if (verificationError) return json({ error: verificationError }, 400);

  const allFiles = await listHandbookFiles(env, fetchImpl);
  const generationFiles = allFiles.filter(file => file.attributes?.generation_id === generationID && file.attributes?.source === PIPELINE_SOURCE);
  const filesByChunkID = new Map();
  const expectedChunkIDs = new Set(run.chunkIDs);
  for (const file of generationFiles) {
    const chunkID = file.attributes?.chunk_id;
    if (!chunkID || !expectedChunkIDs.has(chunkID) || filesByChunkID.has(chunkID)) return json({ error: `Generation ${generationID} contains duplicate or invalid chunk files.` }, 409);
    filesByChunkID.set(chunkID, file);
  }
  const missing = run.chunkIDs.filter(chunkID => !filesByChunkID.has(chunkID));
  if (missing.length) return json({ active: false, status: "uploading", completed: generationFiles.length, expected: run.chunkCount }, 202);
  const failed = generationFiles.filter(file => file.status === "failed" || file.status === "cancelled");
  if (failed.length) return json({ error: `${failed.length} handbook chunk files failed OpenAI indexing.` }, 409);
  const pending = generationFiles.filter(file => file.status !== "completed");
  if (pending.length) return json({ active: false, status: "processing", completed: generationFiles.length - pending.length, expected: run.chunkCount }, 202);

  for (const verification of input.verificationQueries) {
    const results = await searchHandbook(env, verification.query, generationID, fetchImpl);
    const resultChunkIDs = (results.data || []).map(result => result.attributes?.chunk_id).filter(Boolean);
    if (!resultChunkIDs.includes(verification.expectedChunkID)) {
      return json({
        active: false,
        status: "verifying",
        completed: run.chunkCount,
        expected: run.chunkCount,
        verification: { expectedChunkID: verification.expectedChunkID, resultChunkIDs, resultCount: results.data?.length || 0 }
      }, 202);
    }
  }

  const previousActive = await env.HANDBOOK_INDEX_STATE.get(ACTIVE_INDEX_KEY, "json");
  const active = {
    generationID,
    contentVersion: run.contentVersion,
    sourceHash: run.sourceHash,
    chunkCount: run.chunkCount,
    uploadedFileIDs: generationFiles.map(file => file.id),
    activatedAt: new Date().toISOString()
  };
  await env.HANDBOOK_INDEX_STATE.put(ACTIVE_INDEX_KEY, JSON.stringify(active));
  await env.HANDBOOK_INDEX_STATE.put(runKey(generationID), JSON.stringify({ ...run, uploadedFileIDs: active.uploadedFileIDs, status: "active", activatedAt: active.activatedAt }));

  const keepGenerations = new Set([generationID, previousActive?.generationID].filter(Boolean));
  const prune = allFiles.filter(file => file.attributes?.source === PIPELINE_SOURCE && !keepGenerations.has(file.attributes?.generation_id));
  const cleanupWarnings = await cleanupFiles(prune, env, fetchImpl);
  return json({ active: true, generationID, verifiedQueries: input.verificationQueries.length, cleanupWarnings });
}

async function uploadChunk(chunk, generationID, env, fetchImpl) {
  const filename = `handbook-${generationID}-${safeFilename(chunk.id)}.md`;
  const uploaded = await uploadHandbookFile(env, filename, chunk.text, fetchImpl);
  try {
    await attachHandbookFile(env, uploaded.id, {
      source: PIPELINE_SOURCE,
      generation_id: generationID,
      content_version: chunk.contentVersion,
      chunk_id: chunk.id,
      chapter_id: chunk.chapterID,
      section_id: chunk.sectionID,
      block_ids: JSON.stringify(chunk.blockIDs)
    }, fetchImpl);
  } catch (error) {
    await deleteOpenAIFile(env, uploaded.id, fetchImpl).catch(() => {});
    throw error;
  }
  return uploaded.id;
}

async function cleanupFiles(files, env, fetchImpl) {
  const warnings = [];
  const selected = files.slice(0, MAX_CLEANUP_FILES);
  for (let index = 0; index < selected.length; index += 10) {
    const settled = await Promise.allSettled(selected.slice(index, index + 10).map(file => deleteOpenAIFile(env, file.id, fetchImpl)));
    const failures = settled.filter(result => result.status === "rejected").length;
    if (failures) warnings.push(`${failures} old derived files could not be deleted.`);
  }
  if (files.length > MAX_CLEANUP_FILES) warnings.push(`${files.length - MAX_CLEANUP_FILES} old derived files remain for a later cleanup pass.`);
  return warnings;
}

function validateStartRequest(input) {
  if (!input || typeof input !== "object") return "A start request is required.";
  if (!Number.isInteger(input.contentVersion) || input.contentVersion < 1) return "contentVersion must be a positive integer.";
  if (typeof input.sourceHash !== "string" || !/^[a-f0-9]{64}$/.test(input.sourceHash)) return "sourceHash must be a SHA-256 hash.";
  if (typeof input.generationID !== "string" || input.generationID !== `v${input.contentVersion}-${input.sourceHash.slice(0, 12)}`) return "generationID does not match the content version and source hash.";
  if (!Number.isInteger(input.chunkCount) || input.chunkCount < 1) return "chunkCount must be a positive integer.";
  if (!Array.isArray(input.chunkIDs) || input.chunkIDs.length !== input.chunkCount || new Set(input.chunkIDs).size !== input.chunkIDs.length) return "chunkIDs must contain every unique chunk ID.";
  if (!input.chunkIDs.every(id => typeof id === "string" && id.length > 0 && id.length <= 512)) return "Every chunk ID must be a non-empty string of at most 512 characters.";
  return null;
}

function validateChunkBatch(input, run) {
  if (!input || !Array.isArray(input.chunks) || !input.chunks.length || input.chunks.length > MAX_CHUNKS_PER_REQUEST) return `chunks must contain between 1 and ${MAX_CHUNKS_PER_REQUEST} items.`;
  if (new Set(input.chunks.map(chunk => chunk?.id)).size !== input.chunks.length) return "A chunk batch cannot contain duplicate IDs.";
  const expectedIDs = new Set(run.chunkIDs);
  for (const chunk of input.chunks) {
    if (!chunk || typeof chunk !== "object" || !expectedIDs.has(chunk.id)) return "Every chunk must belong to the indexing manifest.";
    if (chunk.contentVersion !== run.contentVersion) return `Chunk ${chunk.id} has the wrong content version.`;
    for (const field of ["chapterID", "chapterTitle", "sectionID", "sectionTitle", "text"]) {
      if (typeof chunk[field] !== "string" || !chunk[field].trim()) return `Chunk ${chunk.id} must include ${field}.`;
    }
    if (chunk.text.length > 64000) return `Chunk ${chunk.id} text is too large.`;
    if (!Array.isArray(chunk.blockIDs) || !chunk.blockIDs.length || !chunk.blockIDs.every(id => typeof id === "string" && id)) return `Chunk ${chunk.id} must include blockIDs.`;
    if (JSON.stringify(chunk.blockIDs).length > 512) return `Chunk ${chunk.id} block_ids metadata exceeds 512 characters.`;
  }
  return null;
}

function validateVerificationQueries(queries, run) {
  if (!Array.isArray(queries) || !queries.length || queries.length > 10) return "verificationQueries must contain between 1 and 10 items.";
  const chunkIDs = new Set(run.chunkIDs);
  if (!queries.every(item => item && typeof item.query === "string" && item.query.trim() && chunkIDs.has(item.expectedChunkID))) return "Every verification query must reference a manifest chunk.";
  return null;
}

function safeFilename(value) {
  return value.replace(/[^a-zA-Z0-9_-]+/g, "-").slice(0, 180);
}

function arraysEqual(left, right) {
  return Array.isArray(left) && Array.isArray(right) && left.length === right.length && left.every((value, index) => value === right[index]);
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json; charset=utf-8" } });
}
