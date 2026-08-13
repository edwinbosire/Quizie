import { createOpenAIRequest, validateGeneratedResult, validateRequest } from "./flashcards.js";
import { extractHandbookSearchResults, getActiveHandbookIndex, retrievalSupportsSelection } from "./handbook-knowledge.js";
import { handleHandbookAdminRequest } from "./handbook-ingestion.js";
import { OpenAIRequestError, openAIJSON } from "./openai-client.js";

export function createWorker({ fetchImpl = globalThis.fetch } = {}) {
  return {
    async fetch(request, env) {
      const adminResponse = await handleHandbookAdminRequest(request, env, fetchImpl);
      if (adminResponse) return adminResponse;
      const url = new URL(request.url);
      if (request.method !== "POST" || url.pathname !== "/flashcards/generate") {
        return json({ error: "Not found." }, 404);
      }
      if (!env.OPENAI_API_KEY) {
        return json({ error: "The flashcard service is not configured." }, 503);
      }
      if (!env.HANDBOOK_VECTOR_STORE_ID) {
        return json({ error: "The handbook search service is not configured." }, 503);
      }
      const activeIndex = await getActiveHandbookIndex(env);
      if (!activeIndex) return json({ error: "The handbook search index has not been activated." }, 503);

      let input;
      try {
        input = await request.json();
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

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
}
