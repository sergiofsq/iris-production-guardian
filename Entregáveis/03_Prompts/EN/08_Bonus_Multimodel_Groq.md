# Bonus — Multi-model (second real AI provider)

## Prompt

```text
Add real access to a second AI provider, free and with no credit card, for
the RAG Assistant's generation — not a clone that pretends to use another
model. Research at least 3 real options (e.g.: Groq, OpenRouter, Cohere,
Mistral) and choose considering: free tier without a card, simplicity of
integration via pure HTTP (no SDK, no Python), and usage limits.

Scope: only the GENERATION needs to switch providers. Reuse the
retrieval/embeddings already indexed with the current provider —
re-ingesting the whole corpus into a new vector space just to "prove
multi-model" has no real value, and the second provider may not even offer
an embeddings endpoint (confirm before assuming it does).

1. Create a new client (same pattern as the existing client: pure
   %Net.HttpRequest, key always from Ens.Config.Credentials, never in
   code) with the same method contract (Generate(prompt) -> text).
2. Make the RAG generation method able to receive which client to use,
   without duplicating the retrieval/prompt/abstention logic.
3. Create a second page/menu entry using the new client.
4. Test the real call BEFORE fixing the model name — if the API returns an
   error saying the model does not exist, query the API's own
   model-listing endpoint instead of guessing another name.
5. Test end to end through the real PAGE (not just the isolated client):
   investigate a component, go to the second provider's page, use the
   suggested question from the investigation context, and confirm a real,
   cited answer — not an undue abstention.
```

## Real result (not the expected one — the observed one)

- Provider chosen: **Groq** (free tier without a card, API compatible with
  OpenAI's Chat Completions format, more generous limits than the
  alternatives evaluated). Discarded in this round: Cohere (same
  non-commercial-use restriction already discarded when choosing the main
  provider), OpenRouter (tighter free tier), Mistral (lower experimentation
  rate limit).
- **Confirmed, not assumed**: Groq **has no embeddings endpoint** on the
  free tier (only chat/generation, a transcription model and a few guard
  models) — checked against `/openai/v1/models` with the real key before
  deciding the architecture. This reinforces that reusing the main
  provider's embeddings was the right decision, not a shortcut.
- `Guardian.RAG.Query.Ask` gained a `pGenerationClient` parameter (default
  the original client) instead of duplicating all the
  retrieval/prompt/abstention logic in the new page.
- **Wrong model name on the first attempt, corrected by the API itself**:
  a general-purpose Llama model that existed in the agent's knowledge
  returned a real `404` ("does not exist or you do not have access to it")
  — Groq's catalog had changed. Fixed by querying `/openai/v1/models`
  with the real key and choosing a model actually available at the time of
  the test.
- Tested end to end through the real page (not just the isolated client):
  login → Investigator → second provider's RAG Assistant → suggested
  question from the investigation context → real, cited answer with
  actionable steps — confirming that it is not a clone pretending to use
  another model.
- The menu label was renamed from the generic "new model" placeholder to
  the provider's real name as soon as the choice was confirmed — including
  the page's `<title>`, which had hardcoded (non-internationalized) text,
  easy to forget in a rename like this.

Full dated evidence:
`docs/planejamento/04_FASE_3_RAG_ASSISTANT.md` §3.1.1.
