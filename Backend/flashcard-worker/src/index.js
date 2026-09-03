import { isAuthorized } from "./auth.js";
import { createOpenAIRequest, validateGeneratedResult, validateRequest } from "./flashcards.js";
import { extractHandbookSearchResults, getActiveHandbookIndex, retrievalSupportsSelection } from "./handbook-knowledge.js";
import { handleHandbookAdminRequest } from "./handbook-ingestion.js";
import { OpenAIRequestError, openAIJSON } from "./openai-client.js";

// Generation is billable, so the route is closed by default: it needs a caller
// token and stays under a per-client rate limit even once authenticated.
const MAX_REQUEST_BYTES = 262_144;

export function createWorker({ fetchImpl = globalThis.fetch } = {}) {
  return {
    async fetch(request, env) {
      const adminResponse = await handleHandbookAdminRequest(request, env, fetchImpl);
      if (adminResponse) return adminResponse;
      const url = new URL(request.url);
      if (request.method !== "POST" || url.pathname !== "/flashcards/generate") {
        return json({ error: "Not found." }, 404);
      }
      if (!env.OPENAI_API_KEY || !env.FLASHCARD_APP_TOKEN) {
        return json({ error: "The flashcard service is not configured." }, 503);
      }
      if (!await isAuthorized(request, env.FLASHCARD_APP_TOKEN)) {
        return json({ error: "Unauthorized." }, 401);
      }
      const rateLimited = await isRateLimited(request, env);
      if (rateLimited) return json({ error: "Too many flashcard requests. Please try again shortly." }, 429);
      if (!env.HANDBOOK_VECTOR_STORE_ID) {
        return json({ error: "The handbook search service is not configured." }, 503);
      }
      const activeIndex = await getActiveHandbookIndex(env);
      if (!activeIndex) return json({ error: "The handbook search index has not been activated." }, 503);

      const body = await readBoundedBody(request);
      if (body === null) return json({ error: `The request body must be at most ${MAX_REQUEST_BYTES} bytes.` }, 413);

      let input;
      try {
        input = JSON.parse(body);
      } catch {
        return json({ error: "A valid JSON request is required." }, 400);
      }
      const validationError = validateRequest(input);
      if (validationError) return json({ error: validationError }, 400);

      let responseBody;
      try {
        responseBody = await openAIJSON(env, "/responses", { method: "POST", body: JSON.stringify(createOpenAIRequest(input, env, activeIndex)) }, fetchImpl);
      } catch (error) {
        if (error instanceof OpenAIRequestError) return json({ error: error.message || "OpenAI could not generate flashcards." }, error.status);
        console.error(JSON.stringify({ event: "flashcard_generation_error", message: error.message }));
        return json({ error: "OpenAI could not generate flashcards." }, 502);
      }
      const searchResults = extractHandbookSearchResults(responseBody, activeIndex);
      if (!retrievalSupportsSelection(searchResults, input)) return json({ error: "Handbook retrieval did not verify the selected source blocks." }, 502);

      const outputText = responseBody.output
        ?.flatMap(item => item.type === "message" ? item.content || [] : [])
        .find(content => content.type === "output_text")?.text;
      if (!outputText) return json({ error: "OpenAI returned no structured flashcards." }, 502);

      try {
        const result = JSON.parse(outputText);
        if (!validateGeneratedResult(result, input)) return json({ error: "OpenAI returned flashcards without valid handbook source blocks." }, 502);
        return json(result);
      } catch {
        return json({ error: "OpenAI returned an invalid structured response." }, 502);
      }
    }
  };
}

export default createWorker();

// Returns null when the body exceeds the cap, so an oversized payload is
// rejected before it can be parsed or forwarded to OpenAI.
async function readBoundedBody(request) {
  const declaredLength = Number(request.headers.get("Content-Length"));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_REQUEST_BYTES) return null;
  const body = await request.text();
  return new TextEncoder().encode(body).length > MAX_REQUEST_BYTES ? null : body;
}

async function isRateLimited(request, env) {
  if (!env.FLASHCARD_RATE_LIMIT) return false;
  const clientKey = request.headers.get("CF-Connecting-IP") || "unknown";
  const { success } = await env.FLASHCARD_RATE_LIMIT.limit({ key: clientKey });
  return !success;
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
}
