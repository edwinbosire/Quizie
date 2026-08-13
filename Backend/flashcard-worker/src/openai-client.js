const OPENAI_BASE_URL = "https://api.openai.com/v1";

export class OpenAIRequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function openAIJSON(env, path, options = {}, fetchImpl = globalThis.fetch) {
  const headers = new Headers(options.headers);
  headers.set("Authorization", `Bearer ${env.OPENAI_API_KEY}`);
  if (options.body && !(options.body instanceof FormData)) headers.set("Content-Type", "application/json");
  const response = await fetchImpl(`${OPENAI_BASE_URL}${path}`, { ...options, headers });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new OpenAIRequestError(response.status, body?.error?.message || `OpenAI request failed with status ${response.status}.`);
  return body;
}

export async function uploadHandbookFile(env, filename, content, fetchImpl = globalThis.fetch) {
  const form = new FormData();
  form.set("purpose", "assistants");
  form.set("file", new Blob([content], { type: "text/markdown" }), filename);
  return openAIJSON(env, "/files", { method: "POST", body: form }, fetchImpl);
}

export async function attachHandbookFile(env, fileID, attributes, fetchImpl = globalThis.fetch) {
  return openAIJSON(env, `/vector_stores/${encodeURIComponent(env.HANDBOOK_VECTOR_STORE_ID)}/files`, {
    method: "POST",
    body: JSON.stringify({
      file_id: fileID,
      attributes,
      chunking_strategy: { type: "static", static: { max_chunk_size_tokens: 4096, chunk_overlap_tokens: 0 } }
    })
  }, fetchImpl);
}

export async function listHandbookFiles(env, fetchImpl = globalThis.fetch) {
  const files = [];
  let after;
  for (let page = 0; page < 200; page += 1) {
    const search = new URLSearchParams({ limit: "100", order: "asc" });
    if (after) search.set("after", after);
    const result = await openAIJSON(env, `/vector_stores/${encodeURIComponent(env.HANDBOOK_VECTOR_STORE_ID)}/files?${search}`, {}, fetchImpl);
    files.push(...(result.data || []));
    if (!result.has_more) return files;
    after = result.last_id || result.data?.at(-1)?.id;
    if (!after) throw new Error("OpenAI returned an invalid vector-store file cursor.");
  }
  throw new Error("OpenAI vector-store file listing exceeded the pagination limit.");
}

export function searchHandbook(env, query, generationID, fetchImpl = globalThis.fetch) {
  return openAIJSON(env, `/vector_stores/${encodeURIComponent(env.HANDBOOK_VECTOR_STORE_ID)}/search`, {
    method: "POST",
    body: JSON.stringify({
      query,
      max_num_results: 6,
      rewrite_query: true,
      filters: { type: "eq", key: "generation_id", value: generationID }
    })
  }, fetchImpl);
}

export async function deleteOpenAIFile(env, fileID, fetchImpl = globalThis.fetch) {
  return openAIJSON(env, `/files/${encodeURIComponent(fileID)}`, { method: "DELETE" }, fetchImpl);
}
