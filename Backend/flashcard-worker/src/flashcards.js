import { createHandbookFileSearchTool } from "./handbook-knowledge.js";

export const SYSTEM_INSTRUCTIONS = `Generate flashcards strictly from the supplied handbook context. Do not introduce external knowledge.

You must search the configured handbook vector store before generating cards. Use retrieved handbook content to verify the selected text, but generate cards only for facts contained in the user's selection and supplied context blocks.

Identify the distinct, testable facts contained in the user's selected text. Use surrounding and adjacent blocks only to resolve meaning and wording. Do not create filler cards and do not force the maximum number of cards. A short single-fact selection should normally produce one card. Split longer selections by atomic fact so every card tests exactly one relationship between one cue and one answer.

Do not copy or lightly reformat quiz questions. Never emit multiple-choice wording (for example “which of these”, “which two”, “select”, or “choose”), true/false prompts, negative prompts, list questions, compound questions, or questions that depend on pronouns or missing context. Turn the source fact into a direct, self-contained recall question with exactly one possible target.

Make the answer the smallest sufficient retrieval unit. Prefer one word, a date or year, a person's name, a place name, an organisation, or a short named term. Target one to five words and never exceed eight. Never put a list, explanation, reason, supporting clause, or second fact in an answer. If the source contains several names, dates, places, or claims, create separate cards only when each can be asked unambiguously.

Good cards:
- “When was Magna Carta agreed?” → “1215”
- “Who developed the World Wide Web?” → “Sir Tim Berners-Lee”
- “Which flower represents England?” → “The rose”
- “Where is Snowdonia?” → “Wales”

Bad cards:
- “Which TWO territories are British Overseas Territories?” → a list of two places
- “Which of the following is correct?” → an answer copied from an option
- “Who signed it?” → a pronoun-dependent cue
- “Why was Magna Carta important?” → an explanatory answer
- “Who was John Constable?” → a biographical paragraph instead of asking for the name from one identifying fact

Each question and answer must contain only one sentence. Questions must end with a question mark. Keep questions under 25 words.

Every answer must be fully supported by the supplied context. Every card must include sourceBlockIds, and every sourceBlockIds entry must identify a supplied block that directly supports that card.`;

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
    isAtomicQuestion(card.question) && isMinimalAnswer(card.answer) &&
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
            question: { type: "string", minLength: 1, maxLength: 180 },
            answer: { type: "string", minLength: 1, maxLength: 80 },
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

export function isSingleSentence(value) {
  const trimmed = value.trim();
  if (!trimmed || /[\r\n]/.test(trimmed)) return false;
  return (trimmed.match(/[.!?]+/g) || []).length <= 1;
}

export function isAtomicQuestion(value) {
  const trimmed = value.trim();
  if (!trimmed.endsWith("?") || !isSingleSentence(trimmed) || wordCount(trimmed) > 24) return false;
  if (/^Who (?:was|is) (?:[A-Z][\p{L}'’-]*|[A-Z])(?:\s+(?:of|the|de|van|[A-Z][\p{L}'’-]*|[A-Z]))+(?:\s*\([^)]*\))?\?$/u.test(trimmed)) return false;
  return !QUESTION_ANTI_PATTERNS.some(pattern => pattern.test(trimmed));
}

export function isMinimalAnswer(value) {
  const trimmed = value.trim();
  if (!isSingleSentence(trimmed) || wordCount(trimmed) > 8) return false;
  const withoutTerminator = trimmed.replace(/[.!?]+$/g, "");
  return !ANSWER_ANTI_PATTERNS.some(pattern => pattern.test(withoutTerminator));
}

const QUESTION_ANTI_PATTERNS = [
  /\b(?:which\s+(?:one|two|three)|which\s+of\s+(?:these|the\s+following)|what\s+(?:one|two|three)|select|choose|true\s+or\s+false)\b/i,
  /\b(?:not|never|except)\b/i,
  /\b(?:statement|statements|option|options)\b.*\b(?:correct|true|false)\b/i,
  /\b(?:and|or)\s+(?:who|what|when|where|which|why|how)\b/i,
  /\b(?:it|they|them|these|those|this|he|she|former|latter)\b/i,
  /_{2,}|\.{3}/
];

const ANSWER_ANTI_PATTERNS = [
  /[,;()\n•]/,
  /\b(?:and|or|who|which|that|where|because|is|are|was|were|has|have|can|should|must|will|would)\b/i,
  /\balso\b/i,
  /^(?:yes|no|true|false|all|none|both|either|neither)\b/i,
  /^(?:he|she|it|they|there)\b/i
];

function wordCount(value) {
  return value.trim().split(/\s+/).filter(Boolean).length;
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
