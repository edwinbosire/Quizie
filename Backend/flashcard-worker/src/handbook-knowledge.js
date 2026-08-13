export const ACTIVE_INDEX_KEY = "handbook:index:active";
export const RUN_KEY_PREFIX = "handbook:index:run:";
export const VERSION_KEY_PREFIX = "handbook:index:version:";

export async function getActiveHandbookIndex(env) {
  if (!env.HANDBOOK_INDEX_STATE) return null;
  return env.HANDBOOK_INDEX_STATE.get(ACTIVE_INDEX_KEY, "json");
}

export function createHandbookFileSearchTool(env, activeIndex) {
  return {
    type: "file_search",
    vector_store_ids: [env.HANDBOOK_VECTOR_STORE_ID],
    max_num_results: 6,
    filters: { type: "eq", key: "generation_id", value: activeIndex.generationID }
  };
}

export function extractHandbookSearchResults(responseBody, activeIndex) {
  return (responseBody.output || [])
    .filter(item => item.type === "file_search_call")
    .flatMap(item => item.results || [])
    .filter(result => result.attributes?.generation_id === activeIndex.generationID)
    .map(result => ({ ...result, blockIDs: parseBlockIDs(result.attributes?.block_ids) }));
}

export function retrievalSupportsSelection(results, input) {
  const selectedBlockIDs = new Set(input.blocks.filter(block => block.isSelected).map(block => block.id));
  return selectedBlockIDs.size > 0 && results.some(result => result.blockIDs.some(blockID => selectedBlockIDs.has(blockID)));
}

export function parseBlockIDs(value) {
  if (typeof value !== "string") return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) && parsed.every(item => typeof item === "string") ? parsed : [];
  } catch {
    return [];
  }
}

export function runKey(generationID) {
  return `${RUN_KEY_PREFIX}${generationID}`;
}

export function versionKey(contentVersion) {
  return `${VERSION_KEY_PREFIX}${contentVersion}`;
}
