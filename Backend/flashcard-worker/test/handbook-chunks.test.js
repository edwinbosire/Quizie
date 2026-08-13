import assert from "node:assert/strict";
import test from "node:test";
import { readFile } from "node:fs/promises";
import { buildHandbookManifest, HANDBOOK_CHUNK_MAX_WORDS } from "../src/handbook-chunks.js";

const fixture = {
  content_version: 7,
  chapters: [{
    id: "chapter_1",
    title: "Chapter 1: Values",
    sections: [{
      id: "section_1",
      title: "Shared values",
      content: [
        { id: "heading_1", type: "heading", level: 3, text: "Democracy" },
        { id: "paragraph_1", type: "paragraph", text: "People vote in elections." },
        { id: "list_1", type: "bulletList", items: ["Respect the law", "Respect others"] },
        { id: "heading_2", type: "heading", level: 3, text: "Population" },
        { id: "table_1", type: "table", rows: [["Year", "Population"], ["1901", "40 million"]] }
      ],
      facts_id: "facts_1",
      facts: ["Democracy is a shared value."]
    }]
  }]
};

test("builds deterministic semantic chunks without crossing headings", () => {
  const bytes = Buffer.from(JSON.stringify(fixture));
  const first = buildHandbookManifest(fixture, bytes);
  const second = buildHandbookManifest(fixture, bytes);

  assert.deepEqual(first, second);
  assert.equal(first.generationID, `v7-${first.sourceHash.slice(0, 12)}`);
  assert.equal(first.chunks.length, 3);
  assert.deepEqual(first.chunks[0].blockIDs, ["heading_1", "paragraph_1", "list_1"]);
  assert.deepEqual(first.chunks[1].blockIDs, ["heading_2", "table_1"]);
  assert.deepEqual(first.chunks[2].blockIDs, ["facts_1"]);
  assert.match(first.chunks[0].text, /### Democracy/);
  assert.doesNotMatch(first.chunks[0].text, /### Population/);
  assert.match(first.chunks[1].text, /\| Year \| Population \|/);
  assert.match(first.chunks[2].text, /Check that you understand/);
});

test("repeats heading context when a semantic topic needs multiple chunks", () => {
  const longParagraph = Array(95).fill("word").join(" ");
  const content = [{ id: "heading", type: "heading", level: 3, text: "Topic" }];
  for (let index = 0; index < 5; index += 1) content.push({ id: `paragraph_${index}`, type: "paragraph", text: longParagraph });
  const handbook = {
    content_version: 1,
    chapters: [{ id: "chapter", title: "Chapter", sections: [{ id: "section", title: "Section", content }] }]
  };
  const manifest = buildHandbookManifest(handbook, Buffer.from(JSON.stringify(handbook)));

  assert.ok(manifest.chunks.length > 1);
  assert.ok(manifest.chunks.every(chunk => chunk.blockIDs[0] === "heading"));
  assert.ok(manifest.chunks.every(chunk => chunk.text.includes("### Topic")));
  assert.ok(manifest.chunks.every(chunk => chunk.text.split(/\s+/).length <= HANDBOOK_CHUNK_MAX_WORDS + 10));
});

test("rejects duplicate IDs, unknown types, and empty authored content", () => {
  const duplicate = structuredClone(fixture);
  duplicate.chapters[0].sections[0].content[1].id = "heading_1";
  assert.throws(() => buildHandbookManifest(duplicate, Buffer.from("duplicate")), /Duplicate handbook id/);

  const unknown = structuredClone(fixture);
  unknown.chapters[0].sections[0].content[0].type = "image";
  assert.throws(() => buildHandbookManifest(unknown, Buffer.from("unknown")), /Unknown handbook block type/);

  const empty = structuredClone(fixture);
  empty.chapters[0].sections[0].content[1].text = " ";
  assert.throws(() => buildHandbookManifest(empty, Buffer.from("empty")), /is empty/);
});

test("builds the production handbook including all table shapes", async () => {
  const bytes = await readFile(new URL("../../../Quizie/Resources/Data/handbook.json", import.meta.url));
  const handbook = JSON.parse(bytes.toString("utf8"));
  const manifest = buildHandbookManifest(handbook, bytes);
  const tableIDs = ["section_04_01_block_014", "section_05_04_block_005", "section_05_04_block_009"];

  assert.equal(manifest.contentVersion, handbook.content_version);
  assert.ok(manifest.chunkCount > 0);
  for (const tableID of tableIDs) {
    const chunk = manifest.chunks.find(candidate => candidate.blockIDs.includes(tableID));
    assert.ok(chunk, `Expected a chunk containing ${tableID}`);
    assert.match(chunk.text, /\|/);
  }
});
