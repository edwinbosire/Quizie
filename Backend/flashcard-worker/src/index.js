const SYSTEM_INSTRUCTIONS = `Generate flashcards strictly from the supplied handbook context. Do not introduce external knowledge.

Identify the distinct, testable facts contained in the user's selected text. Use surrounding and adjacent blocks only to resolve meaning and wording. Do not create filler cards and do not force the maximum number of cards. A short single-fact selection should normally produce one card; longer selections may produce several cards grouped by semantic unit. Every answer must be fully supported by the supplied context. Every sourceBlockIds entry must identify a supplied block that directly supports the card.`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/flashcards/generate") {
      return json({ error: "Not found." }, 404);
    }
    if (!env.OPENAI_API_KEY) {
      return json({ error: "The flashcard service is not configured." }, 503);
    }

    let input;
    try {
      input = await request.json();
    } catch {
      return json({ error: "A valid JSON request is required." }, 400);
    }
    const validationError = validateRequest(input);
    if (validationError) return json({ error: validationError }, 400);

    const allowedBlockIds = [...new Set(input.blocks.map(block => block.id))];
    const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: env.OPENAI_MODEL || "gpt-5.6-luna",
        store: false,
        reasoning: { effort: "none" },
        input: [
          { role: "system", content: SYSTEM_INSTRUCTIONS },
          { role: "user", content: JSON.stringify(input) }
        ],
        text: {
          format: {
            type: "json_schema",
            name: "handbook_flashcards",
            strict: true,
            schema: flashcardSchema(input.maxCards, allowedBlockIds)
          }
        }
      })
    });

    const responseBody = await openAIResponse.json();
    if (!openAIResponse.ok) {
      return json({ error: responseBody?.error?.message || "OpenAI could not generate flashcards." }, openAIResponse.status);
    }

    const outputText = responseBody.output
      ?.flatMap(item => item.type === "message" ? item.content || [] : [])
      .find(content => content.type === "output_text")?.text;
    if (!outputText) return json({ error: "OpenAI returned no structured flashcards." }, 502);

    try {
      const result = JSON.parse(outputText);
      return json(result);
    } catch {
      return json({ error: "OpenAI returned an invalid structured response." }, 502);
    }
  }
};

function flashcardSchema(maxCards, allowedBlockIds) {
  return {
    type: "object",
    properties: {
      cards: {
        type: "array",
        minItems: 1,
        maxItems: maxCards,
        items: {
          type: "object",
          properties: {
            question: { type: "string", minLength: 1 },
            answer: { type: "string", minLength: 1 },
            sourceBlockIds: {
              type: "array",
              minItems: 1,
              items: { type: "string", enum: allowedBlockIds }
            }
          },
          required: ["question", "answer", "sourceBlockIds"],
          additionalProperties: false
        }
      }
    },
    required: ["cards"],
    additionalProperties: false
  };
}

function validateRequest(input) {
  if (!input || typeof input !== "object") return "A request body is required.";
  for (const field of ["chapter", "section", "selection", "context"]) {
    if (typeof input[field] !== "string" || !input[field].trim()) return `${field} is required.`;
  }
  if (!Array.isArray(input.blocks) || !input.blocks.length) return "At least one context block is required.";
  if (!input.blocks.every(block => typeof block.id === "string" && block.id && typeof block.text === "string" && typeof block.isSelected === "boolean")) {
    return "Every context block must include id, text, and isSelected.";
  }
  if (!Number.isInteger(input.maxCards) || input.maxCards < 1 || input.maxCards > 8) return "maxCards must be between 1 and 8.";
  return null;
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
}

export { SYSTEM_INSTRUCTIONS, flashcardSchema, validateRequest };
