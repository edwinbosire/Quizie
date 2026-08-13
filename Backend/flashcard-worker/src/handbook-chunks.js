import { createHash } from "node:crypto";

export const HANDBOOK_CHUNK_MIN_WORDS = 120;
export const HANDBOOK_CHUNK_MAX_WORDS = 350;
export const HANDBOOK_BLOCK_IDS_ATTRIBUTE_LIMIT = 512;

export function buildHandbookManifest(handbook, sourceBytes) {
  assertObject(handbook, "The handbook must be a JSON object.");
  if (!Number.isInteger(handbook.content_version) || handbook.content_version < 1) throw new Error("content_version must be a positive integer.");
  if (!Array.isArray(handbook.chapters) || !handbook.chapters.length) throw new Error("The handbook must contain chapters.");

  const identities = new Set();
  const authoredBlockIDs = new Set();
  const chunks = [];
  const sourceHash = createHash("sha256").update(sourceBytes).digest("hex");
  const generationID = `v${handbook.content_version}-${sourceHash.slice(0, 12)}`;

  for (const chapter of handbook.chapters) {
    validateIdentity(chapter?.id, "chapter", identities);
    const chapterTitle = requiredText(chapter?.title, `Chapter ${chapter?.id || "<unknown>"} has no title.`);
    if (!Array.isArray(chapter.sections) || !chapter.sections.length) throw new Error(`Chapter ${chapter.id} must contain sections.`);

    for (const section of chapter.sections) {
      validateIdentity(section?.id, "section", identities);
      const sectionTitle = requiredText(section?.title, `Section ${section?.id || "<unknown>"} has no title.`);
      if (!Array.isArray(section.content)) throw new Error(`Section ${section.id} content must be an array.`);

      const blocks = section.content.map(item => normalizeBlock(item, identities, authoredBlockIDs));
      const facts = normalizeFacts(section, identities, authoredBlockIDs);
      if (facts) blocks.push(facts);
      chunks.push(...chunkSection({
        contentVersion: handbook.content_version,
        chapterID: chapter.id,
        chapterTitle,
        sectionID: section.id,
        sectionTitle,
        blocks
      }));
    }
  }

  validateCoverage(chunks, authoredBlockIDs);
  for (const chunk of chunks) validateChunkMetadata(chunk);
  return { generationID, contentVersion: handbook.content_version, sourceHash, chunkCount: chunks.length, chunks };
}

function normalizeBlock(item, identities, authoredBlockIDs) {
  assertObject(item, "Every content block must be an object.");
  validateIdentity(item.id, "block", identities);
  authoredBlockIDs.add(item.id);

  switch (item.type) {
  case "paragraph": {
    const text = requiredText(item.text, `Block ${item.id} is empty.`);
    const bullet = text.match(/^[·•]\s*(.+)$/s);
    return { id: item.id, kind: "content", text: bullet ? `- ${bullet[1].trim()}` : text };
  }
  case "heading": {
    const text = requiredText(item.text, `Heading ${item.id} is empty.`);
    const level = Number.isInteger(item.level) ? Math.min(6, Math.max(3, item.level)) : 3;
    return { id: item.id, kind: "heading", text: `${"#".repeat(level)} ${text}` };
  }
  case "bulletList": {
    if (!Array.isArray(item.items) || !item.items.length) throw new Error(`Bullet list ${item.id} is empty.`);
    const items = item.items.map((value, index) => requiredText(value, `Bullet ${index + 1} in ${item.id} is empty.`));
    return { id: item.id, kind: "content", text: items.map(value => `- ${value}`).join("\n") };
  }
  case "table":
    return { id: item.id, kind: "content", text: renderTable(item) };
  default:
    throw new Error(`Unknown handbook block type ${JSON.stringify(item.type)} in ${item.id}.`);
  }
}

function normalizeFacts(section, identities, authoredBlockIDs) {
  if (section.facts == null) return null;
  if (!Array.isArray(section.facts)) throw new Error(`Facts in ${section.id} must be an array.`);
  const facts = section.facts.map(value => typeof value === "string" ? value.trim() : "").filter(Boolean);
  if (!facts.length) return null;
  validateIdentity(section.facts_id, "facts block", identities);
  authoredBlockIDs.add(section.facts_id);
  return { id: section.facts_id, kind: "standalone", text: `### Check that you understand\n${facts.map(value => `- ${value}`).join("\n")}` };
}

function renderTable(item) {
  if (!Array.isArray(item.rows) || !item.rows.length) throw new Error(`Table ${item.id} has no rows.`);
  const rows = item.rows.map((row, rowIndex) => {
    if (!Array.isArray(row) || !row.length) throw new Error(`Row ${rowIndex + 1} in table ${item.id} is empty.`);
    return row.map((cell, columnIndex) => escapeTableCell(requiredText(cell, `Cell ${columnIndex + 1} in row ${rowIndex + 1} of ${item.id} is empty.`)));
  });
  const columnCount = Math.max(...rows.map(row => row.length));
  const padded = rows.map(row => [...row, ...Array(columnCount - row.length).fill("")]);
  const header = padded[0];
  return [
    `| ${header.join(" | ")} |`,
    `| ${header.map(() => "---").join(" | ")} |`,
    ...padded.slice(1).map(row => `| ${row.join(" | ")} |`)
  ].join("\n");
}

function chunkSection(context) {
  const segments = [];
  let current = { heading: null, content: [] };

  for (const block of context.blocks) {
    if (block.kind === "heading") {
      if (current.heading || current.content.length) segments.push(current);
      current = { heading: block, content: [] };
    } else if (block.kind === "standalone") {
      if (current.heading || current.content.length) segments.push(current);
      segments.push({ heading: null, content: [block] });
      current = { heading: null, content: [] };
    } else {
      current.content.push(block);
    }
  }
  if (current.heading || current.content.length) segments.push(current);

  return segments.flatMap(segment => chunkSegment(context, segment));
}

function chunkSegment(context, segment) {
  const groups = [];
  let group = [];
  let words = segment.heading ? wordCount(segment.heading.text) : 0;

  for (const block of segment.content) {
    const blockWords = wordCount(block.text);
    if (group.length && words + blockWords > HANDBOOK_CHUNK_MAX_WORDS) {
      groups.push(group);
      group = [];
      words = segment.heading ? wordCount(segment.heading.text) : 0;
    }
    group.push(block);
    words += blockWords;
    if (words >= HANDBOOK_CHUNK_MIN_WORDS) {
      groups.push(group);
      group = [];
      words = segment.heading ? wordCount(segment.heading.text) : 0;
    }
  }
  if (group.length) groups.push(group);
  if (!groups.length && segment.heading) groups.push([]);

  if (groups.length > 1) {
    const finalGroup = groups.at(-1);
    const previousGroup = groups.at(-2);
    const combinedWords = wordCount([segment.heading?.text, ...previousGroup.map(block => block.text), ...finalGroup.map(block => block.text)].filter(Boolean).join("\n"));
    if (combinedWords <= HANDBOOK_CHUNK_MAX_WORDS) groups.splice(-2, 2, [...previousGroup, ...finalGroup]);
  }

  return groups.map(group => makeChunk(context, segment.heading, group));
}

function makeChunk(context, heading, blocks) {
  const blockIDs = [heading?.id, ...blocks.map(block => block.id)].filter(Boolean);
  const digest = createHash("sha256").update(JSON.stringify([context.chapterID, context.sectionID, blockIDs])).digest("hex").slice(0, 12);
  const id = `${context.chapterID}:${context.sectionID}:${blockIDs[0]}:${digest}`;
  const text = [
    `# ${context.chapterTitle}`,
    `## ${context.sectionTitle}`,
    heading?.text,
    ...blocks.map(block => block.text)
  ].filter(Boolean).join("\n\n");
  if (!text.trim()) throw new Error(`Generated chunk ${id} is empty.`);
  return {
    id,
    contentVersion: context.contentVersion,
    chapterID: context.chapterID,
    chapterTitle: context.chapterTitle,
    sectionID: context.sectionID,
    sectionTitle: context.sectionTitle,
    blockIDs,
    text
  };
}

function validateCoverage(chunks, authoredBlockIDs) {
  const represented = new Set(chunks.flatMap(chunk => chunk.blockIDs));
  const missing = [...authoredBlockIDs].filter(id => !represented.has(id));
  if (missing.length) throw new Error(`Handbook blocks missing from chunks: ${missing.join(", ")}.`);
}

export function validateChunkMetadata(chunk) {
  const encodedBlockIDs = JSON.stringify(chunk.blockIDs);
  if (encodedBlockIDs.length > HANDBOOK_BLOCK_IDS_ATTRIBUTE_LIMIT) throw new Error(`Chunk ${chunk.id} block_ids metadata exceeds ${HANDBOOK_BLOCK_IDS_ATTRIBUTE_LIMIT} characters.`);
  for (const [name, value] of Object.entries({ chunk_id: chunk.id, chapter_id: chunk.chapterID, section_id: chunk.sectionID })) {
    if (value.length > 512) throw new Error(`Chunk ${chunk.id} ${name} metadata exceeds 512 characters.`);
  }
}

function validateIdentity(value, kind, identities) {
  if (typeof value !== "string" || !value.trim()) throw new Error(`Every ${kind} must have a non-empty id.`);
  if (identities.has(value)) throw new Error(`Duplicate handbook id ${value}.`);
  identities.add(value);
}

function requiredText(value, error) {
  if (typeof value !== "string" || !value.trim()) throw new Error(error);
  return value.trim();
}

function assertObject(value, error) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(error);
}

function wordCount(text) {
  return text.trim().split(/\s+/u).filter(Boolean).length;
}

function escapeTableCell(value) {
  return value.replaceAll("|", "\\|").replaceAll("\n", " ");
}
