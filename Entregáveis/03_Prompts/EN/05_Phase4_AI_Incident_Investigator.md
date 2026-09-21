# Phase 4 — AI Incident Investigator

## Prompt

```text
Implement the AI Incident Investigator: given a real Production component
(chosen from a list coming from the same StatusCollector as the Monitor —
never free text) and a time window, produce a summary with hypotheses kept
separate from observations, without inventing a confidence percentage.

1. Guardian.Investigator.EvidenceCollector — gathers REAL evidence: the
   component's current health (reuses StatusCollector), events in the
   window (Ens.MessageHeader, with the real error highlighted via
   $System.Status.GetErrorText, not the raw %Status), and the most
   relevant RAG documents about that component (reuses
   Guardian.RAG.Query.Retrieve — refactor to expose pure retrieval,
   without generation, if it does not exist yet).
2. Guardian.Investigator.Analyzer — builds a structured prompt from that
   real evidence and asks the AI model for: summary, observations,
   hypotheses (explicitly separated from observed fact), evidence gaps,
   suggested next steps. Never invent events or a confidence percentage
   that the evidence does not support.
3. Guardian.UI.InvestigatorPage — form with the real component and the
   window, showing current health, list of events, the AI analysis, and
   the documentation used as context.
4. Persist each investigation (component, window, analysis) so it can be
   reviewed later and to feed the RAG Assistant with the context of the
   latest investigation.

Test against the real history of the Phase 1 failure/recovery experiment —
the window must really cover the incident, and the analysis must cite the
real metric (not a suspicious round value).
```

## Real result (not the expected one — the observed one)

- **Real date-calculation bug**: the first version of the window cutoff
  calculation only handled a rollover of exactly 1 day
  (`tSecs + 86400`), enough for the Monitor's fixed window but not for a
  configurable window of several days — it produced a still-negative value
  and `$ZDATETIME` rejected it with `<ILLEGAL VALUE>`. Fixed by
  decomposing the whole window into days + seconds before subtracting.
- **The raw `Ens.MessageHeader.ErrorStatus` is not readable text** — it is
  a serialized `%Status` with control characters mixed into the text,
  unusable directly on screen or in the AI prompt. Solved with
  `$System.Status.GetErrorText()`, confirmed against real messages from
  the Phase 1 failure experiment.
- **Finding recorded, neither hidden nor fixed because it affects nothing
  visible**: `TIMESTAMP` columns return a meaningless large number when
  read via `%SQL.Statement`/`%Get` instead of `CAST(... AS VARCHAR)` — it
  already existed since Phase 3 (RAG), confirmed not to be a regression of
  this phase. Recorded so it is not mistaken for a new bug.
- Tested against 3 real components, including a real `503` from Gemini
  during the test (not simulated) — the Investigator reported the real
  unavailability instead of freezing or inventing an analysis.
- IntegratedML remains confirmed **unavailable** (proprietary package
  missing from the image) — not part of this phase, Phase 0 blocker
  maintained, not worked around.

Full dated evidence:
`docs/planejamento/05_FASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md`.
