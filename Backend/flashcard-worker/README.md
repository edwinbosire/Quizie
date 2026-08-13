# Quizie handbook AI backend

This Worker keeps OpenAI credentials out of the iOS application and derives a traceable retrieval index from Quizie's canonical `Quizie/Resources/Data/handbook.json` file.

The app sends handbook context to `POST /flashcards/generate`. The Worker forces OpenAI file search against the active handbook generation, requires a retrieved chunk to overlap a selected source block, and returns strict structured cards with validated `sourceBlockIds`.

## Handbook index

`handbook.json` is the source of truth. The chunk manifest, uploaded Markdown files, embeddings, vector-store contents, and active-generation state are derived data.

The deterministic builder:

- keeps chapter, section, and heading boundaries;
- combines adjacent blocks toward 120 words without exceeding 350 words unless one authored block is larger;
- preserves paragraphs, lists, tables, and check-understanding facts;
- emits one OpenAI file per semantic chunk with chapter, section, chunk, block, version, and generation attributes;
- rejects missing or duplicate identities, unknown block types, empty content, incomplete coverage, and oversized metadata.

Validate or inspect the current source without network access:

```sh
npm run handbook:validate
npm run handbook:index -- --dry-run
```

To index and activate a handbook generation, set `HANDBOOK_API_BASE_URL` to the deployed Worker origin and set `HANDBOOK_INGEST_TOKEN` to the same secret configured on the Worker, then run:

```sh
npm run handbook:index
```

The CLI uploads resumable batches, waits for every OpenAI vector-store file to complete, verifies one representative semantic query per chapter, and only then activates the generation. Identical source hashes are no-ops. If handbook content changes, increment `content_version`; the Worker rejects changed content with an unchanged active version.

Activation keeps the immediately previous generation so requests reading a cached KV value continue to work during global propagation. On later activations, older pipeline-owned files are pruned. Existing unrelated or manually uploaded vector-store files are never removed by the cleanup path.

### Indexing API

All indexing routes require `Authorization: Bearer <HANDBOOK_INGEST_TOKEN>`:

- `POST /admin/handbook/index/start`
- `POST /admin/handbook/index/:generationID/chunks`
- `POST /admin/handbook/index/:generationID/activate`

## Local development

1. Install dependencies with `npm install`.
2. Copy `.dev.vars.example` to `.dev.vars` and add a restricted development project key plus a long random ingest token. `.dev.vars` is ignored by Git.
3. Run `npm run dev`.
4. Set the Quizie scheme environment variable `FLASHCARD_API_BASE_URL` to the worker URL printed by Wrangler.

Local Wrangler uses local KV state. To index the deployed service, point `HANDBOOK_API_BASE_URL` at its HTTPS origin rather than the local development URL.

## Deployment

1. Authenticate Wrangler for the intended Cloudflare account.
2. Store the key with `npx wrangler secret put OPENAI_API_KEY`.
3. Store a separate long random token with `npx wrangler secret put HANDBOOK_INGEST_TOKEN`.
4. Deploy with `npm run deploy`. Wrangler provisions the `HANDBOOK_INDEX_STATE` KV namespace declared in `wrangler.jsonc` when it is not already bound.
5. Run `npm run handbook:index` against the deployed origin to create and activate the first generation.
6. Set the app build setting `FLASHCARD_API_BASE_URL` to the deployed HTTPS worker origin.

Do not put `OPENAI_API_KEY` or `HANDBOOK_INGEST_TOKEN` in the app target, `Info.plist`, an `.xcconfig` used by the app, or this repository. Before a public launch, protect the flashcard endpoint with the app's user authentication and server-side rate limits.
