# Phase 4 — AI Incident Investigator / IntegratedML / API

> Consolidates the implementation of the third MVP module. IntegratedML is
> already recorded as blocked (VR-003, `07_EVIDENCE_SCORECARD.md`) — not pursued
> in this phase. The public API remains an open pending item.

## 1. Scope (context, section 2)

- Receive an incident/component + time interval; gather metrics, events and
  authorized documentation excerpts.
- Produce a summary, evidence, hypotheses, gaps and next steps, with traceable
  references.
- Separate observation from hypothesis: correlation does not prove root cause.
- Do not display invented confidence percentages.
- Read-only in the MVP — no automatic remediation.
- Persist enough context to review an investigation later.

Proposed acceptance: in the known failure scenario, the answer points to real
evidence and admits when there is not enough information; model unavailability
does not prevent consulting the evidence.

## 2. Implementation (10/09/2026)

Three new classes in `Guardian.Investigator.*`, plus a page:

- **`Guardian.Investigator.Schema`** — DDL of the table
  `Guardian_Investigator.Investigation` (Component, WindowMinutes, CreatedAt,
  EventCount, DocumentCount, ModelAvailable, Analysis) — same pattern as
  `Guardian.RAG.Schema`. Deliberately simplified schema: there are no separate
  "hypotheses"/"gaps" columns because the Analyzer does not extract them as
  structured fields — storing them separately would be faking data that was not
  actually computed.
- **`Guardian.Investigator.EvidenceCollector`** — gathers real evidence for a
  component + time window:
  - Current health: reuses `Guardian.Monitor.StatusCollector` (Phase 2), with
    no duplication of the healthy/degraded/unavailable/unknown logic.
  - Real events: `Ens.MessageHeader` filtered by
    `SourceConfigName`/`TargetConfigName` and time window, with the error text
    converted via `$System.Status.GetErrorText` — verified live that it turns the
    raw serialized value of `ErrorStatus` (`"0  i<Ens>ErrFailureTimeout..."`)
    into readable text (`"ERROR <Ens>ErrFailureTimeout: FailureTimeout of 15
    seconds... ERROR #5005: Cannot open file..."`).
  - Relevant documentation: reuses `Guardian.RAG.Query.Retrieve` (the hybrid
    search of Phase 3 — see section 3 below about that refactor), using the
    component name + the text of the errors found as the query.
  - A RAG failure (embeddings unavailable) is isolated in a `Try/Catch` - it
    cannot prevent the collection of metrics/events, an explicit acceptance
    requirement.
- **`Guardian.Investigator.Analyzer`** — assembles a prompt with the real
  evidence (`BuildPrompt`) and asks Gemini for a summary/observations/
  hypotheses/gaps/next steps, with an explicit instruction not to invent a
  confidence percentage and to separate observation from hypothesis. If the
  model fails, the collected evidence remains available (`modelAvailable = 0`,
  the page shows the evidence normally) — the same resilience pattern already
  used in the RAG Assistant. Since 20/09/2026 it has an automatic fallback: if
  Gemini fails (e.g. HTTP 503 for high demand), the same prompt is sent to Groq.
- **`Guardian.UI.InvestigatorPage`** — form (real component, via a dropdown
  populated by `StatusCollector`; window in minutes), shows current health, the
  event list (with the real error highlighted), cited documentation and the AI
  analysis. Persists each investigation in the table above. Same visual theme as
  the other pages (`assets/css/iris-guardian-theme.css`).

The events listed are the messages in which the chosen component is the source
**or** the target, so the neighboring host (for example the
`IncidentRouterProcess` for a Priority operation) appears as the other end of
each message.

## 3. RAG refactor: `Guardian.RAG.Query.Retrieve`

`Guardian.RAG.Query.Ask` performed retrieval + generation in a single call. So
that the Investigator could reuse the hybrid search without triggering an
unnecessary text generation (the final generation is done only once, with all
the evidence together, in the `Analyzer`), retrieval was extracted into its own
method, `Retrieve(pQuestion)`, returning `{sources, bestSimilarity,
contextText}`. `Ask` now calls `Retrieve` internally and keeps exactly the same
public behavior — tested after the refactor: same question ("error #5005"), same
result (`abstained=0`, similarity 0.677, 5 sources) as before the refactor.

## 4. Real bugs found and fixed

1. **Time-window cutoff with `<ILLEGAL VALUE>`**: the first version of
   `EvidenceCollector` computed the date cutoff by handling only an exact
   1-day rollover (`Set tSecs = tSecs + 86400`), enough for the Monitor's fixed
   `ErrorWindowSeconds` but not for a user-configurable window — a window of
   several days produced a seconds value that was still negative after the
   single adjustment, and `$ZDATETIME` rejected it with `<ILLEGAL VALUE>`. Fixed
   by decomposing the entire window into days + seconds before subtracting.
2. **Raw `ErrorStatus` is not readable text**: `Ens.MessageHeader.ErrorStatus`
   stores a serialized `%Status` (a mix of control characters and text, e.g.
   `"0  i<Ens>ErrFailureTimeoutPERROR #5005..."`) — it cannot be shown directly
   to the user nor passed to the AI prompt without treatment. Solved with
   `$System.Status.GetErrorText()`, confirmed live against real error messages
   from the Phase 1 failure/recovery experiment.

## 5. Finding recorded, not fixed in this phase

`TIMESTAMP` columns (`CreatedAt` in `Guardian_Investigator.Investigation` and
also in `Guardian_RAG.Document`/`Chunk`, already in production since Phase 3)
return a meaningless large number (e.g. `1154710572020846976`) when read via
`%SQL.Statement` + `%Get`/`%Display`, instead of a readable date. It is not a
regression of this phase — confirmed that the RAG table already had exactly the
same behavior. It does not affect anything displayed today (no page shows that
field), so it was not fixed now — recorded so it is not confused with a new bug
if someone notices it later.

## 6. Real test (10/09/2026)

Investigation of `Guardian.Operation.FileOutputOperation` against the real
history of the Phase 1 failure/recovery experiment (a window large enough to
cover the 09/09/2026 data):

- 20 real events retrieved, including the 3 failure episodes (`INC-003`,
  `INC-003b`, `INC-MONITOR`) with the correct `#5005` error.
- Current health reported as `unavailable` (real data of the Production being
  stopped at the time of the test, not fabricated).
- The generated analysis correctly separated OBSERVATIONS (failure counts,
  times, recoveries) from HYPOTHESES (possible causes), with no invented
  confidence percentage, and identified as a legitimate GAP the discrepancy
  between `unavailable` and `recent errors=0` — a real finding that the analysis
  itself correctly flagged as uncertainty, not as fact.
- Investigation persisted in `Guardian_Investigator.Investigation` (confirmed
  by SQL).

### 6.1 More components tested (10/09/2026)

Post-Phase 4 reinforcement: the other two hosts of the Production, same real
history, same large window.

- **`Guardian.Service.FileIncidentService`**: the Gemini API returned a **real
  503** ("This model is currently experiencing high demand") during the test —
  not simulated. `modelAvailable=0`, but the 10 real events of the window
  remained available in the evidence, confirming live (not only in theory) the
  acceptance requirement: "model unavailability does not prevent consulting the
  evidence".
- **`Guardian.Process.IncidentRouterProcess`**: current health `healthy`
  (unlike `FileOutputOperation`, which was `unavailable` — the Investigator
  reports the real state of each component, not a fixed value). 20 events
  retrieved, including the 2 real failures that pass through this host before
  reaching the Operation. The analysis separated observation from hypothesis
  correctly and flagged as a real gap the absence of an operating system log to
  confirm the exact cause of the permission failure.

With the three hosts of the Production tested (Service, Process, Operation), the
Investigator has evidence of working correctly both on the happy path (analysis
generated) and on the path where the AI model itself fails (evidence preserved,
analysis not generated) — the two behaviors the acceptance requires.

## 7. Pending

- IntegratedML: blocked (VR-003), out of MVP scope.
- Suitable public API (bonus): not started.
