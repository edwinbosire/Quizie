import assert from "node:assert/strict";
import test from "node:test";
import { SYSTEM_INSTRUCTIONS, createOpenAIRequest, flashcardSchema, isSingleSentence, validateGeneratedResult, validateRequest } from "../src/flashcards.js";
import { createWorker } from "../src/index.js";

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

test("requires single-sentence cards with concise answers", () => {
  assert.match(SYSTEM_INSTRUCTIONS, /never exceed 12 words/);
  assert.equal(isSingleSentence("Who signed Magna Carta?"), true);
  assert.equal(isSingleSentence("Who signed it? Why was it signed?"), false);

  const concise = { cards: [{ question: "Who signed Magna Carta?", answer: "King John.", sourceBlockIds: ["block-1"] }] };
  const multipleSentences = { cards: [{ question: "Who signed it? Why?", answer: "King John.", sourceBlockIds: ["block-1"] }] };
  const verboseAnswer = { cards: [{ question: "Who signed Magna Carta?", answer: "King John signed it after a prolonged dispute with powerful English barons at Runnymede.", sourceBlockIds: ["block-1"] }] };

  assert.equal(validateGeneratedResult(concise, validRequest), true);
  assert.equal(validateGeneratedResult(multipleSentences, validRequest), false);
  assert.equal(validateGeneratedResult(verboseAnswer, validRequest), false);
});

test("forces file search against the configured handbook vector store", () => {
  const request = createOpenAIRequest(validRequest, {
    OPENAI_MODEL: "gpt-5.6-luna",
    HANDBOOK_VECTOR_STORE_ID: "vs_test"
  }, { generationID: "v1-abc123" });

  assert.deepEqual(request.tools, [{
    type: "file_search",
    vector_store_ids: ["vs_test"],
    max_num_results: 6,
    filters: { type: "eq", key: "generation_id", value: "v1-abc123" }
  }]);
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

test("requires an active index before generating flashcards", async () => {
  const worker = createWorker({ fetchImpl: async () => assert.fail("OpenAI should not be called") });
  const response = await worker.fetch(new Request("https://example.com/flashcards/generate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(validRequest)
  }), {
    OPENAI_API_KEY: "key",
    HANDBOOK_VECTOR_STORE_ID: "vs_test",
    HANDBOOK_INDEX_STATE: new MemoryKV()
  });

  assert.equal(response.status, 503);
  assert.match((await response.json()).error, /has not been activated/);
});

test("accepts flashcards only when retrieval overlaps a selected block", async () => {
  let openAIRequest;
  const worker = createWorker({
    fetchImpl: async (_url, options) => {
      openAIRequest = JSON.parse(options.body);
      return Response.json({
        output: [
          { type: "file_search_call", results: [{ attributes: { generation_id: "v1-abc123", block_ids: '["block-1"]' } }] },
          { type: "message", content: [{ type: "output_text", text: JSON.stringify({ cards: [{ question: "What principle?", answer: "Democracy.", sourceBlockIds: ["block-1"] }] }) }] }
        ]
      });
    }
  });
  const state = new MemoryKV({ "handbook:index:active": { generationID: "v1-abc123" } });
  const response = await worker.fetch(new Request("https://example.com/flashcards/generate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(validRequest)
  }), { OPENAI_API_KEY: "key", HANDBOOK_VECTOR_STORE_ID: "vs_test", HANDBOOK_INDEX_STATE: state });

  assert.equal(response.status, 200);
  assert.equal(openAIRequest.tools[0].max_num_results, 6);
  assert.equal(openAIRequest.tools[0].filters.value, "v1-abc123");
});

test("rejects retrieval results from a stale generation", async () => {
  const worker = createWorker({
    fetchImpl: async () => Response.json({
      output: [
        { type: "file_search_call", results: [{ attributes: { generation_id: "v0-stale", block_ids: '["block-1"]' } }] },
        { type: "message", content: [{ type: "output_text", text: JSON.stringify({ cards: [{ question: "What principle?", answer: "Democracy.", sourceBlockIds: ["block-1"] }] }) }] }
      ]
    })
  });
  const state = new MemoryKV({ "handbook:index:active": { generationID: "v1-abc123" } });
  const response = await worker.fetch(new Request("https://example.com/flashcards/generate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(validRequest)
  }), { OPENAI_API_KEY: "key", HANDBOOK_VECTOR_STORE_ID: "vs_test", HANDBOOK_INDEX_STATE: state });

  assert.equal(response.status, 502);
  assert.match((await response.json()).error, /did not verify/);
});

class MemoryKV {
  constructor(values = {}) {
    this.values = new Map(Object.entries(values).map(([key, value]) => [key, JSON.stringify(value)]));
  }

  async get(key, type) {
    const value = this.values.get(key);
    if (value == null) return null;
    return type === "json" ? JSON.parse(value) : value;
  }

  async put(key, value) {
    this.values.set(key, value);
  }
}
