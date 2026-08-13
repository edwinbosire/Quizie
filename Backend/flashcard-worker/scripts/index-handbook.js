#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { buildHandbookManifest } from "../src/handbook-chunks.js";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const defaultSource = resolve(scriptDirectory, "../../../Quizie/Resources/Data/handbook.json");
const options = parseArguments(process.argv.slice(2));
const sourceBytes = await readFile(options.source);
const handbook = JSON.parse(sourceBytes.toString("utf8"));
const manifest = buildHandbookManifest(handbook, sourceBytes);

console.log(`Validated handbook v${manifest.contentVersion}: ${manifest.chunkCount} semantic chunks (${manifest.generationID}).`);
if (options.validate) process.exit(0);
if (options.dryRun) {
  const byChapter = Object.groupBy(manifest.chunks, chunk => chunk.chapterID);
  for (const [chapterID, chunks] of Object.entries(byChapter)) console.log(`  ${chapterID}: ${chunks.length} chunks`);
  process.exit(0);
}

const baseURL = options.baseURL || process.env.HANDBOOK_API_BASE_URL;
const token = process.env.HANDBOOK_INGEST_TOKEN;
if (!baseURL) throw new Error("Set HANDBOOK_API_BASE_URL or pass --base-url.");
if (!token) throw new Error("Set HANDBOOK_INGEST_TOKEN.");

const start = await request("/admin/handbook/index/start", {
  contentVersion: manifest.contentVersion,
  sourceHash: manifest.sourceHash,
  chunkCount: manifest.chunkCount,
  chunkIDs: manifest.chunks.map(chunk => chunk.id),
  generationID: manifest.generationID
});
if (start.noOp) {
  console.log("The active handbook index already matches this source.");
  process.exit(0);
}

for (let offset = 0; offset < manifest.chunks.length; offset += options.batchSize) {
  const chunks = manifest.chunks.slice(offset, offset + options.batchSize);
  const result = await request(`/admin/handbook/index/${encodeURIComponent(manifest.generationID)}/chunks`, { chunks });
  console.log(`Indexed ${Math.min(offset + chunks.length, manifest.chunkCount)}/${manifest.chunkCount} chunks (${result.uploaded} uploaded, ${result.skipped} resumed).`);
}

const verificationQueries = Object.values(Object.groupBy(manifest.chunks, chunk => chunk.chapterID)).map(chunks => {
  const chunk = chunks[0];
  return { query: verificationText(chunk.text), expectedChunkID: chunk.id };
});
let activation;
for (let attempt = 0; attempt < 90; attempt += 1) {
  activation = await request(`/admin/handbook/index/${encodeURIComponent(manifest.generationID)}/activate`, { verificationQueries }, [202]);
  if (activation.active) break;
  await new Promise(resolvePromise => setTimeout(resolvePromise, Math.min(10000, 1000 + attempt * 250)));
}
if (!activation?.active) throw new Error("Timed out waiting for OpenAI to finish indexing the handbook.");

console.log(`Activated ${manifest.generationID}; verified ${activation.verifiedQueries} representative searches.`);
for (const warning of activation.cleanupWarnings || []) console.warn(`Cleanup warning: ${warning}`);

async function request(path, body, acceptedStatuses = []) {
  const response = await fetch(new URL(path, ensureTrailingSlash(baseURL)), {
    method: "POST",
    headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok && !acceptedStatuses.includes(response.status)) throw new Error(result.error || `Index request failed with status ${response.status}.`);
  return result;
}

function parseArguments(argumentsList) {
  const parsed = { source: defaultSource, batchSize: 8, validate: false, dryRun: false, baseURL: null };
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--validate") parsed.validate = true;
    else if (argument === "--dry-run") parsed.dryRun = true;
    else if (argument === "--source") parsed.source = resolve(argumentsList[++index]);
    else if (argument === "--base-url") parsed.baseURL = argumentsList[++index];
    else if (argument === "--batch-size") parsed.batchSize = Number(argumentsList[++index]);
    else throw new Error(`Unknown argument ${argument}.`);
  }
  if (!Number.isInteger(parsed.batchSize) || parsed.batchSize < 1 || parsed.batchSize > 10) throw new Error("--batch-size must be between 1 and 10.");
  return parsed;
}

function ensureTrailingSlash(value) {
  return value.endsWith("/") ? value : `${value}/`;
}

function verificationText(text) {
  return text.replace(/^#+\s+/gm, "").replace(/\s+/g, " ").trim().slice(0, 2000);
}
