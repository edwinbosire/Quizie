import assert from "node:assert/strict";
import test from "node:test";
import { SYSTEM_INSTRUCTIONS, createOpenAIRequest, flashcardSchema, validateGeneratedResult, validateRequest } from "../src/flashcards.js";

const validRequest = {
  chapter: "Chapter 1: Values",
  section: "Values",
  selection: "Democracy and the rule of law.",
  context: "[block-1] Democracy and the rule of law.",
  blocks: [{ id: "block-1", text: "Democracy and the rule of law.", isSelected: true }],
  maxCards: 1
};

test("requires complete handbook context", () => {
  assert.equal(validateRequest(validRequest), null);
  assert.match(validateRequest({ ...validRequest, context: "" }), /context is required/);
});

test("constrains output count and source block IDs", () => {
  const schema = flashcardSchema(4, ["block-1", "block-2"]);
  assert.equal(schema.properties.cards.maxItems, 4);
  assert.deepEqual(schema.properties.cards.items.properties.sourceBlockIds.items.enum, ["block-1", "block-2"]);
});

test("prohibits external knowledge", () => {
  assert.match(SYSTEM_INSTRUCTIONS, /strictly from the supplied handbook context/);
  assert.match(SYSTEM_INSTRUCTIONS, /Do not introduce external knowledge/);
});

test("forces file search against the configured handbook vector store", () => {
  const request = createOpenAIRequest(validRequest, {
    OPENAI_MODEL: "gpt-5.6-luna",
    HANDBOOK_VECTOR_STORE_ID: "vs_test"
  });

  assert.deepEqual(request.tools, [{ type: "file_search", vector_store_ids: ["vs_test"] }]);
  assert.deepEqual(request.tool_choice, { type: "file_search" });
  assert.deepEqual(request.include, ["file_search_call.results"]);
});

test("requires valid sourceBlockIds on every generated card", () => {
  const valid = { cards: [{ question: "What principle is named?", answer: "Democracy.", sourceBlockIds: ["block-1"] }] };
  const missingSources = { cards: [{ question: "What principle is named?", answer: "Democracy.", sourceBlockIds: [] }] };
  const unknownSource = { cards: [{ question: "What principle is named?", answer: "Democracy.", sourceBlockIds: ["other-block"] }] };

  assert.equal(validateGeneratedResult(valid, validRequest), true);
  assert.equal(validateGeneratedResult(missingSources, validRequest), false);
  assert.equal(validateGeneratedResult(unknownSource, validRequest), false);
});
