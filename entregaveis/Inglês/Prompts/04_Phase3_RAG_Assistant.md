# Phase 3 — RAG Assistant

## Prompt

```text
Decide the AI provider for embeddings and generation — it needs a real
free tier, with no non-commercial-use restriction, confirmed with a real
call (not by the documentation alone) before writing any COS class. Test
at least: ChatGPT/Claude.ai (the chat subscription does NOT give access
to the API, they are separate products — confirm before assuming), Cohere
(check the license of the free tier) and Gemini.

With the chosen provider, implement Guardian.RAG.GeminiClient
(Embed/Generate via pure %Net.HttpRequest — no SDK, no Python), always
read the key from Ens.Config.Credentials, never in code. Configure
outbound SSL (Security.SSLConfigs) using the system CA bundle.

Define the schema (Guardian.RAG.Schema.Setup(), tables via direct CREATE
TABLE, not persistent-class Property): Document, Chunk with IRIS's native
VECTOR column. Choose the embedding dimension with a recorded
justification (cost of VECTOR_COSINE vs. dimension × corpus size).

Implement ingestion with chunking (size and overlap justified), retrieval
(top-K by cosine similarity), generation with a prompt that REQUIRES
source citation, and calibrated abstention: if the best similarity falls
below a threshold, answer "I don't know" instead of making something up —
test the threshold with at least one pair of real questions (one
relevant, one irrelevant) before fixing the value.

Afterwards: add HYBRID search (lexical iFind + vector, fused by
Reciprocal Rank Fusion) without replacing the vector one, and a formal
evaluation set to recalibrate the abstention threshold with more than two
points. Handle real API unavailability (5xx error) with a clear message on
screen, never freezing the page or inventing an answer.
```

## Real result (not the expected one — the observed one)

- **Provider decision with two real rejections**: OpenAI confirmed to have
  no free tier (neither embeddings nor chat) in a live test; Cohere
  discarded because of an explicit non-commercial-use restriction on the
  free tier. **Google Gemini** chosen, with the caveat accepted by the
  owner that the free tier allows the content to be used to improve
  products — only already-public documentation was indexed.
- **Outdated model name corrected by the API itself**:
  `gemini-2.5-flash` returned a real `404` ("no longer available to new
  users... use models/gemini-3.6-flash") — fixed by reading the error, not
  by assumption.
- **3 real IRIS API errors fixed**: `%SQL.Statement` has no
  `%GetLastIdentity()` (use `%ROWID` from the INSERT's result set); `$Get`
  does not work on a `%DynamicObject` property (use `.%Get("key")`); a
  false UTF-8 encoding alarm — the debugging terminal corrupted the
  display of accented characters, but a hexdump of the real HTTP bytes
  confirmed correct UTF-8 end to end (recorded so that the investigation
  is not repeated).
- **Real unavailability observed, not simulated**: the Gemini API really
  returned `503 UNAVAILABLE` during testing — this motivated the
  `Try/Catch` that now shows a clear message instead of bringing the page
  down.
- Abstention threshold calibrated at 0.58 from 2 real points (relevant
  question = 0.653, irrelevant = 0.518) — later formalized with a larger
  evaluation set (`Guardian.RAG.Eval`).
- The **multi-model** bonus (second provider, Groq) came much later, see
  `08_Bonus_Multimodel_Groq.md`.

Full dated evidence: `docs/planejamento/04_FASE_3_RAG_ASSISTANT.md`.
