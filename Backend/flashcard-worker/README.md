# Quizie flashcard generation backend

This worker keeps the OpenAI API key out of the iOS application. The app sends handbook context to `POST /flashcards/generate`; the worker calls the OpenAI Responses API, forces a `file_search` against the configured handbook vector store, and returns strict structured cards with validated `sourceBlockIds`.

## Local development

1. Install dependencies with `npm install`.
2. Copy `.dev.vars.example` to `.dev.vars` and add a restricted development project key. `.dev.vars` is ignored by Git.
3. Run `npm run dev`.
4. Set the Quizie scheme environment variable `FLASHCARD_API_BASE_URL` to the worker URL printed by Wrangler.

## Deployment

1. Authenticate Wrangler for the intended Cloudflare account.
2. Store the key with `npx wrangler secret put OPENAI_API_KEY`.
3. Deploy with `npm run deploy`.
4. Set the app build setting `FLASHCARD_API_BASE_URL` to the deployed HTTPS worker origin.

Do not put `OPENAI_API_KEY` in the app target, `Info.plist`, an `.xcconfig` used by the app, or this repository. Before a public launch, protect the endpoint with the app's user authentication and server-side rate limits.
