import assert from "node:assert/strict";
import test from "node:test";
import { REQUEST_LIMITS, SYSTEM_INSTRUCTIONS, createOpenAIRequest, flashcardSchema, isAtomicQuestion, isMinimalAnswer, isSingleSentence, validateGeneratedResult, validateRequest } from "../src/flashcards.js";
import { createWorker } from "../src/index.js";

const APP_TOKEN = "test-app-token";

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
  assert.match(SYSTEM_INSTRUCTIONS, /tests exactly one relationship/);
  assert.match(SYSTEM_INSTRUCTIONS, /Prefer one word, a date or year, a person's name, a place name/);
  assert.match(SYSTEM_INSTRUCTIONS, /never exceed eight/);
  assert.match(SYSTEM_INSTRUCTIONS, /Do not copy or lightly reformat quiz questions/);
  assert.equal(isSingleSentence("Who signed Magna Carta?"), true);
  assert.equal(isSingleSentence("Who signed it? Why was it signed?"), false);

  const concise = { cards: [{ question: "Who signed Magna Carta?", answer: "King John.", sourceBlockIds: ["block-1"] }] };
  const multipleSentences = { cards: [{ question: "Who signed it? Why?", answer: "King John.", sourceBlockIds: ["block-1"] }] };
  const verboseAnswer = { cards: [{ question: "Who signed Magna Carta?", answer: "King John signed it after a prolonged dispute with powerful English barons at Runnymede.", sourceBlockIds: ["block-1"] }] };

  assert.equal(validateGeneratedResult(concise, validRequest), true);
  assert.equal(validateGeneratedResult(multipleSentences, validRequest), false);
  assert.equal(validateGeneratedResult(verboseAnswer, validRequest), false);
});

test("requires one self-contained recall target and one minimal answer", () => {
  assert.equal(isAtomicQuestion("When was Magna Carta agreed?"), true);
  assert.equal(isAtomicQuestion("Who developed the World Wide Web?"), true);
  assert.equal(isAtomicQuestion("Which TWO people signed it?"), false);
  assert.equal(isAtomicQuestion("Which of these statements is correct?"), false);
  assert.equal(isAtomicQuestion("Who signed it?"), false);
  assert.equal(isAtomicQuestion("Who signed Magna Carta and when?"), false);
  assert.equal(isAtomicQuestion("Magna Carta was agreed in 1215."), false);
  assert.equal(isAtomicQuestion("Who was John Constable?"), false);
  assert.equal(isAtomicQuestion("Who is Sir Edward Elgar (1857–1934)?"), false);

  assert.equal(isMinimalAnswer("1215"), true);
  assert.equal(isMinimalAnswer("Sir Tim Berners-Lee"), true);
  assert.equal(isMinimalAnswer("England and Wales"), false);
  assert.equal(isMinimalAnswer("A scientist who developed the World Wide Web"), false);
  assert.equal(isMinimalAnswer("True"), false);
  assert.equal(isMinimalAnswer("All of these"), false);
  assert.equal(isMinimalAnswer("All of the these"), false);
  assert.equal(isMinimalAnswer("A by-election is held"), false);
  assert.equal(isMinimalAnswer("Cnut, also called Canute"), false);
  assert.equal(isMinimalAnswer("DWP (Department for Work and Pensions)"), false);
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
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${APP_TOKEN}` },
    body: JSON.stringify(validRequest)
  }), {
    OPENAI_API_KEY: "key",
    FLASHCARD_APP_TOKEN: APP_TOKEN,
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
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${APP_TOKEN}` },
    body: JSON.stringify(validRequest)
  }), { OPENAI_API_KEY: "key", FLASHCARD_APP_TOKEN: APP_TOKEN, HANDBOOK_VECTOR_STORE_ID: "vs_test", HANDBOOK_INDEX_STATE: state });

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
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${APP_TOKEN}` },
    body: JSON.stringify(validRequest)
  }), { OPENAI_API_KEY: "key", FLASHCARD_APP_TOKEN: APP_TOKEN, HANDBOOK_VECTOR_STORE_ID: "vs_test", HANDBOOK_INDEX_STATE: state });

  assert.equal(response.status, 502);
  assert.match((await response.json()).error, /did not verify/);
});

test("rejects callers without the app token", async () => {
  const worker = createWorker({ fetchImpl: async () => assert.fail("OpenAI should not be called") });
  const env = { OPENAI_API_KEY: "key", FLASHCARD_APP_TOKEN: APP_TOKEN, HANDBOOK_VECTOR_STORE_ID: "vs_test", HANDBOOK_INDEX_STATE: new MemoryKV() };

  for (const headers of [{}, { Authorization: "Bearer wrong-token" }, { Authorization: APP_TOKEN }]) {
    const response = await worker.fetch(generateRequest({ headers }), env);
    assert.equal(response.status, 401);
    assert.match((await response.json()).error, /Unauthorized/);
  }
});

test("refuses to serve generation when no app token is configured", async () => {
  const worker = createWorker({ fetchImpl: async () => assert.fail("OpenAI should not be called") });
  const response = await worker.fetch(generateRequest(), {
    OPENAI_API_KEY: "key",
    HANDBOOK_VECTOR_STORE_ID: "vs_test",
    HANDBOOK_INDEX_STATE: new MemoryKV()
  });

  assert.equal(response.status, 503);
  assert.match((await response.json()).error, /not configured/);
});

test("rate limits authenticated callers", async () => {
  const worker = createWorker({ fetchImpl: async () => assert.fail("OpenAI should not be called") });
  const response = await worker.fetch(generateRequest(), {
    OPENAI_API_KEY: "key",
    FLASHCARD_APP_TOKEN: APP_TOKEN,
    HANDBOOK_VECTOR_STORE_ID: "vs_test",
    HANDBOOK_INDEX_STATE: new MemoryKV(),
    FLASHCARD_RATE_LIMIT: { limit: async () => ({ success: false }) }
  });

  assert.equal(response.status, 429);
  assert.match((await response.json()).error, /Too many/);
});

test("rejects oversized bodies before parsing them", async () => {
  const worker = createWorker({ fetchImpl: async () => assert.fail("OpenAI should not be called") });
  const oversized = { ...validRequest, selection: "x".repeat(300_000) };
  const response = await worker.fetch(generateRequest({ body: oversized }), {
    OPENAI_API_KEY: "key",
    FLASHCARD_APP_TOKEN: APP_TOKEN,
    HANDBOOK_VECTOR_STORE_ID: "vs_test",
    HANDBOOK_INDEX_STATE: new MemoryKV({ "handbook:index:active": { generationID: "v1-abc123" } })
  });

  assert.equal(response.status, 413);
});

test("bounds every free-text field so input cost stays capped", () => {
  const block = (text, id = "block-1") => ({ id, text, isSelected: true });

  assert.match(validateRequest({ ...validRequest, chapter: "c".repeat(REQUEST_LIMITS.title + 1) }), /chapter must be at most/);
  assert.match(validateRequest({ ...validRequest, selection: "s".repeat(REQUEST_LIMITS.selection + 1) }), /selection must be at most/);
  assert.match(validateRequest({ ...validRequest, context: "c".repeat(REQUEST_LIMITS.context + 1) }), /context must be at most/);
  assert.match(validateRequest({ ...validRequest, blocks: Array.from({ length: REQUEST_LIMITS.blocks + 1 }, (_, index) => block("text", `block-${index}`)) }), /blocks must contain at most/);
  assert.match(validateRequest({ ...validRequest, blocks: [block("t", "b".repeat(REQUEST_LIMITS.blockID + 1))] }), /block id must be at most/);
  assert.match(validateRequest({ ...validRequest, blocks: [block("t".repeat(REQUEST_LIMITS.blockText + 1))] }), /block text must be at most/);

  const wideSpread = Array.from({ length: 50 }, (_, index) => block("t".repeat(REQUEST_LIMITS.blockText), `block-${index}`));
  assert.match(validateRequest({ ...validRequest, blocks: wideSpread }), /must total at most/);
});

test("accepts the largest real handbook section", () => {
  // The biggest section in handbook.json: 104 blocks and ~24k characters.
  const blocks = Array.from({ length: 104 }, (_, index) => ({ id: `section_01_01_block_${index}`, text: "t".repeat(232), isSelected: true }));
  const oversizedSection = { ...validRequest, selection: "s".repeat(24_171), context: "c".repeat(26_000), blocks, maxCards: 8 };

  assert.equal(validateRequest(oversizedSection), null);
});

function generateRequest({ headers = { Authorization: `Bearer ${APP_TOKEN}` }, body = validRequest } = {}) {
  return new Request("https://example.com/flashcards/generate", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body)
  });
}

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
