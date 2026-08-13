import { createHandbookFileSearchTool } from "./handbook-knowledge.js";

export const SYSTEM_INSTRUCTIONS = `Generate flashcards strictly from the supplied handbook context. Do not introduce external knowledge.

You must search the configured handbook vector store before generating cards. Use retrieved handbook content to verify the selected text, but generate cards only for facts contained in the user's selection and supplied context blocks.

Identify the distinct, testable facts contained in the user's selected text. Use surrounding and adjacent blocks only to resolve meaning and wording. Do not create filler cards and do not force the maximum number of cards. A short single-fact selection should normally produce one card; longer selections may produce several cards grouped by semantic unit. Every answer must be fully supported by the supplied context. Every card must include sourceBlockIds, and every sourceBlockIds entry must identify a supplied block that directly supports that card.`;

export function createOpenAIRequest(input, env, activeIndex) {
  const allowedBlockIds = [...new Set(input.blocks.map(block => block.id))];
  return {
    model: env.OPENAI_MODEL || "gpt-5.6-luna",
    store: false,
    reasoning: { effort: "none" },
    input: [
      { role: "system", content: SYSTEM_INSTRUCTIONS },
      { role: "user", content: JSON.stringify(input) }
    ],
    tools: [createHandbookFileSearchTool(env, activeIndex)],
    tool_choice: { type: "file_search" },
    include: ["file_search_call.results"],
    text: {
      format: {
        type: "json_schema",
        name: "handbook_flashcards",
        strict: true,
        schema: flashcardSchema(input.maxCards, allowedBlockIds)
      }
    }
  };
}

export function validateGeneratedResult(result, input) {
  if (!result || !Array.isArray(result.cards) || !result.cards.length || result.cards.length > input.maxCards) return false;
  const allowedBlockIds = new Set(input.blocks.map(block => block.id));
  return result.cards.every(card =>
    typeof card.question === "string" && card.question.trim() &&
    typeof card.answer === "string" && card.answer.trim() &&
    Array.isArray(card.sourceBlockIds) && card.sourceBlockIds.length > 0 &&
    card.sourceBlockIds.every(blockId => allowedBlockIds.has(blockId))
  );
}

export function flashcardSchema(maxCards, allowedBlockIds) {
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

export function validateRequest(input) {
  if (!input || typeof input !== "object") return "A request body is required.";
  for (const field of ["chapter", "section", "selection", "context"]) {
    if (typeof input[field] !== "string" || !input[field].trim()) return `${field} is required.`;
  }
  if (!Array.isArray(input.blocks) || !input.blocks.length) return "At least one context block is required.";
  if (!input.blocks.every(block => typeof block.id === "string" && block.id && typeof block.text === "string" && typeof block.isSelected === "boolean")) {
    return "Every context block must include id, text, and isSelected.";
  }
  if (!input.blocks.some(block => block.isSelected)) return "At least one context block must be selected.";
  if (!Number.isInteger(input.maxCards) || input.maxCards < 1 || input.maxCards > 8) return "maxCards must be between 1 and 8.";
  return null;
}
