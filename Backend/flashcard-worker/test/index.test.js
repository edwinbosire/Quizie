import assert from "node:assert/strict";
import test from "node:test";
import { SYSTEM_INSTRUCTIONS, flashcardSchema, validateRequest } from "../src/index.js";

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
