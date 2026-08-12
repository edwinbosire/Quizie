import { createOpenAIRequest, validateGeneratedResult, validateRequest } from "./flashcards.js";

export default {
  async fetch(request, env) {
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

    let input;
    try {
      input = await request.json();
    } catch {
      return json({ error: "A valid JSON request is required." }, 400);
    }
    const validationError = validateRequest(input);
    if (validationError) return json({ error: validationError }, 400);

    const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(createOpenAIRequest(input, env))
    });

    const responseBody = await openAIResponse.json();
    if (!openAIResponse.ok) {
      return json({ error: responseBody?.error?.message || "OpenAI could not generate flashcards." }, openAIResponse.status);
    }
    const usedHandbookSearch = responseBody.output?.some(item => item.type === "file_search_call");
    if (!usedHandbookSearch) return json({ error: "OpenAI did not search the handbook before generating flashcards." }, 502);

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

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
}
