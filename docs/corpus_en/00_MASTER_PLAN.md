# Master Plan — IRIS Production Guardian

> Living tracking document: phases, dependencies, decisions and schedule.
> The source of truth for scope and assumptions is
> `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`; this file only tracks
> progress and points to where each decision/evidence is recorded. Update it
> with every relevant increment, not retroactively.

## 1. Scope and priorities (summary)

An MVP with three modules — **Production Monitor**, **AI Incident
Investigator**, **RAG Assistant** — on top of InterSystems IRIS, with
COS/ObjectScript as the main language and persistence exclusively in IRIS.
Full detail in `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`,
sections 1–2.

Mandatory technology premise (context, section 1.1): COS first, IRIS as the
only database, Python only for a proven COS limitation. No exception has been
applied so far.

## 2. Phases and associated files

| Phase | File | Status |
|---|---|---|
| Phase 0 — Setup and architecture | `01_PHASE_0_SETUP_ARCHITECTURE.md` | Infrastructure and critical VRs closed. Hybrid search, public API and multi-model bonuses closed (see Phases 3 and 5) |
| Phase 1 — Production COS / interoperability | `02_PHASE_1_PYPROD_INTEROPERABILITY.md` | Complete, including the optional bonus — Service/Process/Operation with a file adapter, real end-to-end message, tested and reproducible failure/recovery scenario (`docs/experiments/01_falha_recuperacao_producao.md`), routing by real Business Rules (`Ens.Rule.Definition`) closed on 10/09/2026, see §6 of that file |
| Phase 2 — Production Monitor / telemetry | `03_PHASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md` | Completed and visually validated. Reinforcement of 10/09/2026: persisted time series (`Guardian_Monitor.HealthSample`) and stuck-host detection, see §6.1 |
| Phase 3 — RAG Assistant | `04_PHASE_3_RAG_ASSISTANT.md` | Complete and tested: ingestion, chunking, vector storage, hybrid retrieval (vector + lexical via iFind, +3 bonus, see §4), generation with citation, calibrated abstention, query page. Visual validation completed on 10/09/2026 (background/logo adjusted) |
| Phase 4 — AI Investigator / IntegratedML / API | `05_PHASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md` | AI Incident Investigator implemented and tested (10/09/2026): real evidence (health + events + documentation) + AI analysis, hypotheses kept separate from observation, no invented confidence. IntegratedML blocked (VR-003), out of scope. Public API closed on 11/09/2026 outside this phase — see `07_EVIDENCE_SCORECARD.md` |
| Phase 5 — Hardening, tests, demo | `06_PHASE_5_HARDENING_TESTS_DEMO.md` | Started 11/09/2026 — scope defined, execution not started (see file) |
| Evidence scorecard | `07_EVIDENCE_SCORECARD.md` | Active — updated every time a VR is closed |

Phase files not yet created will be added when the corresponding phase
starts, not before — this avoids speculative planning that goes stale.

## 3. Schedule (until 21/09/2026)

| Dates | Work and checkpoint | Status on 09/09/2026 |
|---|---|---|
| 08–10/09 | Phase 0: environment, repository, IRIS/containers, architecture, initial dashboard structure | ✅ Environment, critical VRs and namespace/database ready. Initial dashboard covered by the Monitor/RAG, ahead of schedule |
| 11–14/09 | Phase 1 + progress on Phase 2: Production COS, hosts, controlled simulation, Monitor wired to real sources | ✅ **Completed ahead of schedule, on 09/09** — Phase 1 and Phase 2 complete (see section 2) |
| 15–17/09 | Phases 3 and 4: corpus, embeddings, hybrid search, Investigator | 🟡 Phase 3 (RAG) complete, ahead of schedule, on 09/09. Hybrid search (bonus) and Phase 4 (Investigator) not yet started |
| 18–19/09 | Phase 5: API/integrations, tests, clean installation, documentation | Not started |
| 20/09 | Complete demo, recording, README, article, audit of the matrix | README already exists (created 09/09); recording/article pending |
| 21/09 | Final check and submission | Not started |

**Honest reading:** the pace is well ahead of the original schedule — three
phases (0, 1, 2) plus Phase 3 (RAG) already have tested working versions on
day 1 of the real working window. This is a sequencing advance, not
validation that no work is missing: all optional bonuses are already closed
(Business Rules, hybrid search, public API, multi-model), but hardening/formal
tests, video and article are still to be done.

`VERIFY_REQUIRED`: official time/timezone of the submission cut-off — do not
assume 23:59 (inherited from the context, still open).

## 4. Recorded decisions (chronological)

- **09/09/2026** — Docker/IRIS environment validated (Community 2026.2
  ARM64); finding: the `iris-community-arm64` image without multi-arch is
  abandoned, do not use. See `01_PHASE_0_SETUP_ARCHITECTURE.md` §1–2.
- **09/09/2026** — VR-001 (Vector Search) and VR-002 (Foreign Table)
  confirmed, with no license restriction in the Community Edition.
- **09/09/2026** — Own visual identity defined: logo without the
  InterSystems wordmark, palette in `assets/css/iris-guardian-theme.css`.
- **09/09/2026** — WSGI and PyProd dropped as bonuses to pursue (structural
  conflict with the COS-first premise, not a technical pending item).
- **09/09/2026** — VR-003 (IntegratedML/AutoML) confirmed blocked on this
  image; bonus (+3) marked out of MVP scope.
- **09/09/2026** — Namespace `GUARDIAN` and database `GUARDIANDB` created,
  interoperability enabled, verified by command. Dedicated administrative
  user for the project created (credential kept out of Git).
- **09/09/2026** — Development environment configured: VS Code + InterSystems
  ObjectScript extension, named server `guardian-local` (Basic auth, HTTP,
  port 53773), automatic compilation on save in `src/`. See
  `.vscode/settings.json`.
- **09/09/2026** — Phase 1 started: Production
  `Guardian.Production.GuardianProduction` implemented (Service → Process →
  Operation with the `EnsLib.File` adapter), real message tested end to end.
  Bonuses "Service, Process and Operation" (+1) and "Adapter on a host" (+1)
  confirmed with evidence. See `02_PHASE_1_PYPROD_INTEROPERABILITY.md`.
- **09/09/2026** — Fixed the type of `TargetConfigName` to
  `Ens.DataType.ConfigName` (it was `%String`) in the Service and Process
  hosts — required for the Interoperability graphical editor to draw the
  connections between hosts.
- **09/09/2026** — Controlled failure and recovery scenario tested and
  validated twice from scratch (reproducible script in
  `docs/experiments/01_falha_recuperacao_producao.md`): real failure
  (`ERROR #5005`), automatic recovery for new traffic, manual recovery of
  the affected message via `Ens.MessageHeader.ResendMessage`.
- **09/09/2026** — Started organizing the delivery files:
  `docs/experiments/` for reproducible scripts (used when recording the
  contest video) and `README.md` (English, public) at the root.
- **09/09/2026** — Phase 2 (Production Monitor) started: health rules
  documented (healthy/degraded/unavailable/unknown, based only on confirmed
  real data sources — `Ens_Config.Item`, `Ens.Queue`, `Ens.MessageHeader`,
  `Ens.Director`). Implemented `Guardian.Monitor.StatusCollector` (logic),
  `Guardian.API.MonitorAPI` (REST `/api/guardian/status`) and
  `Guardian.UI.MonitorPage` (HTML at `/csp/guardian/Guardian.UI.MonitorPage.cls`).
  Tested against Experiment 1 (real failure): hosts correctly change to
  `degraded` during the failure. Real compilation error found and documented:
  a `Parameter` with an underscore breaks `..#NAME` (the ObjectScript
  concatenation operator interferes with the parser). See `03_PHASE_2_...md`.
- **09/09/2026** — Phase 3 started: AI provider decision (Google Gemini, free
  tier — ChatGPT/Claude.ai discarded because the chat subscription does not
  include an API; OpenAI API has no confirmed free tier; Cohere replaced due
  to a commercial-use restriction). Key stored in `Ens.Config.Credentials`.
  `Guardian.RAG.GeminiClient` implemented and tested live (768-dim embeddings
  + generation). Outbound SSL configuration (`PublicHTTPS`) created for HTTPS
  to public hosts.
- **09/09/2026** — Phase 3 (RAG Assistant) first complete version:
  `Guardian_RAG.Document`/`Chunk` schema (VECTOR 768-dim, direct DDL),
  paragraph chunking with overlap, initial corpus of 79 fragments (the
  project's own docs), `VECTOR_COSINE` retrieval + top 5, generation with
  source citation, abstention calibrated at 0.58 (two real observed points),
  `Guardian.UI.RAGPage` page. Real errors fixed: `%SQL.Statement` without
  `%GetLastIdentity` (use `%ROWID`), wrong property access on a
  `%DynamicObject` via `$Get` (use `%Get`), an encoding false alarm (the bug
  was only terminal display, confirmed by hexdump), and handling of real API
  unavailability (503) without taking the page down. See
  `04_PHASE_3_RAG_ASSISTANT.md`.
- **10/09/2026** — Visual validation of the RAG Assistant by the owner:
  approved, with two adjustments. (1) Background too vivid blue in the first
  version — fixed to a deliberate medium blue (`#3f63a8` body, `#2f4d85`
  header), white content cards for readability. (2) Product logo missing —
  inserted (crop without the tag-line, `assets/iris-guardian-logo-header.png`)
  in a white "badge" in the header. Finding during the adjustment: the theme
  had an automatic dark mode (`prefers-color-scheme: dark`) that reacted to
  the user's OS without all elements (navigation links) having an adapted
  color — dark text on a dark background, poor contrast. Removed; a single
  fixed palette from here on, see `assets/css/iris-guardian-theme.css`. The
  same fix was applied to `Guardian.UI.MonitorPage` for visual consistency
  between the two modules (both now reference the shared theme, which
  previously existed but was never actually loaded by the pages). Logo served
  as a static file in `/durable/csp/guardian/` (physical directory of the CSP
  application `/csp/guardian/`) via `docker cp` — not part of the volume
  versioned in Git, repeat the `docker cp` after recreating the container.
- **10/09/2026** — Hybrid search implemented (+3 bonus, closing the Phase 3
  pending item): `%iFind.Index.Basic` index on
  `Guardian_RAG.Chunk.ChunkText` + Reciprocal Rank Fusion with the existing
  vector search, inside `Guardian.RAG.Query.Ask`. Tested live with a question
  containing an exact error code (`#5005`, retrieved and cited correctly) and
  abstention was re-confirmed on an irrelevant question (0.58 calibration
  intact, since the abstention gate is still based only on pure vector
  similarity, not on the hybrid score). Recorded finding: `%iFind.Rank`
  (iFind's native ranking function) did not accept the expected syntax —
  decision to use a fixed bonus per lexical match instead of inventing an
  uncalculated rank position. See `04_PHASE_3_RAG_ASSISTANT.md` §6.
- **10/09/2026** — Phase 4 (AI Incident Investigator) implemented:
  `Guardian.Investigator.EvidenceCollector` (health via the reused
  `StatusCollector`, real events from `Ens.MessageHeader` with readable error
  text via `$System.Status.GetErrorText`, documentation via
  `Guardian.RAG.Query.Retrieve`), `Guardian.Investigator.Analyzer` (prompt
  that separates observation from hypothesis, forbids invented confidence,
  resilient to model failure), `Guardian.UI.InvestigatorPage`. Refactor in
  `Guardian.RAG.Query`: `Retrieve()` extracted from `Ask()` for reuse without
  duplicate generation — `Ask` behavior confirmed identical after the
  refactor. Two real bugs fixed: multi-day time-window cutoff
  (`<ILLEGAL VALUE>` in `$ZDATETIME`) and conversion of the raw `ErrorStatus`
  from `Ens.MessageHeader`. Tested against the real history of the Phase 1
  failure/recovery experiment — see
  `05_PHASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md`.
- **10/09/2026** — Monitor: persisted time series
  (`Guardian_Monitor.HealthSample`) and stuck-host detection
  (`StatusCollector.IsStuck`), see `03_PHASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md`
  §6.1. RAG: evaluation set of 10 questions (`Guardian.RAG.Eval`) —
  `MinSimilarity` calibration confirmed 10/10 correct (clean gap between
  0.51-0.52 irrelevant and 0.67-0.76 relevant), and a formal A/B comparison
  of chunking (paragraph vs naive fixed window) — paragraph won on similarity
  in 7 of 7 questions, without exception (0.709 vs 0.684 average). See
  `04_PHASE_3_RAG_ASSISTANT.md` §7.
- **10/09/2026** — RAG corpus expanded from 5 to 9 documents: the two missing
  phase docs (`05_PHASE_4`, `07_SCORECARD`) and two real public articles from
  the InterSystems Developer Community (Vector Search, Business Rules)
  obtained via `WebFetch`. Recorded finding: the official documentation
  `docs.intersystems.com` is rendered via JavaScript and `WebFetch` only saw
  the menu, not the article body — the Developer Community (static HTML)
  worked. Tested with a real question about underscores in Business Rules:
  it cited the new public source correctly, cross-checked it against the
  project's internal finding on the same topic, and honestly abstained on the
  part the article (Part 1 of a series) did not cover. See
  `04_PHASE_3_RAG_ASSISTANT.md` §8.
- **10/09/2026** — Investigator tested against the other two hosts of the
  Production (`FileIncidentService`, `IncidentRouterProcess`), same real
  history from Phase 1. `FileIncidentService` hit a **real 503** from Gemini
  during the test — this confirmed live that the evidence remains available
  even when the model is unavailable. `IncidentRouterProcess` came out
  `healthy` (unlike `FileOutputOperation`, which was `unavailable`) and had a
  complete analysis generated correctly. All three hosts of the Production are
  now tested. See `05_PHASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md` §6.1.
- **10/09/2026** — Business Rules (+2 bonus) implemented, closing the last
  pending item of Phase 1: `Guardian.Rule.IncidentRoutingRule`
  (`Ens.Rule.Definition`) decides the incident destination by `Severity`,
  called from inside the Process via `EvaluateRules`. A second Operation
  (`Guardian.Operation.PriorityOutputOperation`) was created to give the rule
  two real destinations. Tested with `HIGH`/`LOW` messages routed to
  different folders and then the rule condition was changed (`MEDIUM` started
  to count as priority) and recompiled without touching the Process — the
  routing outcome changed only because of the rule, proving it is not a
  disguised conditional. Compilation done via `iris session` +
  `$system.OBJ.Load` (the container restarted on its own between sessions —
  `Exited (137)`, cause not investigated, just restarted with
  `docker start`). See `02_PHASE_1_PYPROD_INTEROPERABILITY.md` §6.
- **11/09/2026** — Phase 5 started: scope defined in
  `06_PHASE_5_HARDENING_TESTS_DEMO.md` (installation from a clean checkout,
  formal tests of the four paths required by DoD §11 — full journey,
  destination failure, missing data, model/API unavailability —, secrets
  audit, closing pending items in the scorecard, video recording, community
  article). No execution item completed yet; the execution order is the
  owner's decision.

## 5. Pending register (VERIFY_REQUIRED)

Single register in `07_EVIDENCE_SCORECARD.md`. Summary of what remains open:

- Metrics/queues/logs interfaces for the Monitor.
- ~~Business Rules (real routing)~~ — **closed 10/09/2026**:
  `Guardian.Rule.IncidentRoutingRule` (`Ens.Rule.Definition`), see
  `02_PHASE_1_PYPROD_INTEROPERABILITY.md` §6.
- ~~Multi-model (real access forms per type)~~ — **closed 13/09/2026**:
  second provider Groq (`Guardian.RAG.GroqClient`, `openai/gpt-oss-120b`)
  integrated in `Guardian.UI.RAGAltPage`, tested live end to end, see
  `04_PHASE_3_RAG_ASSISTANT.md` §3.1.1.
- ~~Hybrid search (lexical + vector)~~ — **closed 10/09/2026**: iFind + RRF in
  `Guardian.RAG.Query`, see `04_PHASE_3_RAG_ASSISTANT.md` §6.
- ~~Access to a suitable public API~~ — **closed 11/09/2026**: PublicHealth
  bonus (`Guardian.Production.PublicHealthProduction` doing real polling of
  `disease.sh`), see `07_EVIDENCE_SCORECARD.md`.
- ~~AI provider/model for embeddings and generation~~ — **closed 09/09/2026**:
  Google Gemini API (free tier), see `04_PHASE_3_RAG_ASSISTANT.md`.
- Official submission cut-off time/timezone.
- Interpretation of the bonus/multi-model ceiling by the contest organizers.

Close each item only with observed evidence, recording it in the scorecard.

## 6. Definition of Done (reference)

Full checklist in `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`,
section 11. First item with real progress: the COS Production (Service →
Process → Operation) exists, runs, and has a tested and reproducible
failure/recovery scenario. The three MVP modules (Monitor, Investigator, RAG)
do not yet exist as their own interface. Reassess this section at the end of
each phase.

## 7. Delivery file structure

Organization adopted for the submission (Open Exchange + community article),
consolidated on 09/09/2026, **reorganized on 10/09/2026** so that no file is
left loose at the repository root (owner's standard from here on — do not
create more loose files at the root).

| Path | Content | Public/internal |
|---|---|---|
| `README.md` | Project overview, installation, how to reproduce — in English | Public (Open Exchange). Stays at the root by tool convention (GitHub/Open Exchange only renders the README at the root automatically) |
| `package.json` | Frontend tooling metadata (lint/format/dev server) | Public. Stays at the root by npm convention |
| `docs/planejamento/` (`00_MASTER_PLAN.md` … `07_SCORECARD_EVIDENCIAS.md`, `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`) | Planning, decisions and evidence per phase — in Portuguese | Internal (development context, may accompany the repo as process transparency) |
| `docs/experiments/` | Step-by-step reproducible scripts for each controlled experiment (failure/recovery, future: load, RAG, IntegratedML) — used directly when recording the video | Internal, but referenceable in the article |
| `src/Guardian/` | COS source code (Production classes, messages, hosts) | Public |
| `assets/` | Visual identity (logo, CSS tokens) | Public |
| `pessoal/` (`Estudar.txt`, `Anotações para Usuário.txt`, `Script de Apresentação V1.txt`) | Owner's personal learning/presentation material | **Not** part of the delivery — whole folder in `.gitignore` |
| `Imagens/ImagemMatriz.png` | Logo source art (see `07_EVIDENCE_SCORECARD.md`) | Tracked in git |
| `Imagens/guardian-boas-vindas.png`, `guardian-landing-hero.png`, `guardian-rag-assistant.png` | Additional illustrative/conceptual art (variations of the brand shield — portrait, horizontal hero, RAG composition), generated on 10/09/2026, same spirit as `ImagemMatriz.png` | Tracked in git — decision on public use (README/article/video) still pending, but already versioned |
| `Imagens/Aplicacao/MonitroPage1.jpg`, `MonitroPage2.jpg` | Evidence screenshots **cited by path** in `03_PHASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md` §4.2 and §7 (locale bug, visual validation) | Tracked in git — the citation in the doc now resolves for anyone cloning the repo |
| `Imagens/Config/*.jpg` | Personal configuration screenshots (VS Code, namespace, Production) — not cited in any phase doc | Tracked in git at the owner's explicit request (10/09/2026: "everything in the project folder must be committed") — visually checked before the commit, no exposed credential |
| `Imagens/Error/` (`VSCode.jpg`) | Personal screenshot of a one-off VS Code error | **Not** part of the delivery — explicit exception by the owner (10/09/2026) to the "commit everything" rule, now in `.gitignore` |
| `Imagens/.DS_Store`, `**/Thumbs.db` | Operating-system junk (Finder/Explorer) | In `.gitignore` — not versioned even with the rule above, since it is not project content |

Pending: community article (Portuguese, with the required tags — see context
section 5), explanatory video, and the `README.md` content itself (created in
this session, see `04_...`/commits).

**10/09/2026 — revised versioning policy:** the owner asked for everything
inside the project folder to be committed, with two explicit exceptions, both
in `.gitignore`: (1) `pessoal/` — contains a plain-text credential in
`Anotações para Usuário.txt` (`guardian`/`guardian`) that the owner confirmed
must **not** go to git, keeping the "no versioned secret" rule; (2)
`Imagens/Error/` — personal screenshot of a one-off error, excluded at the
owner's direct request.

## 8. Immediate next step

Phases 0-4 complete, validated and reinforced on 10/09/2026: time series +
stuck host in the Monitor, evaluation set + calibration + chunking comparison
in the RAG, expanded corpus (5→9 docs, including real public documentation),
and the Investigator tested on the three hosts of the Production (including a
real Gemini 503 handled with resilience). Public API (PublicHealth bonus)
closed on 11/09/2026. UI redesigned to a persistent sidebar (`3a850cc`,
11/09/2026) — a subsequent attempt to open Investigator/RAG as a floating
modal was reverted the same day due to UX problems (see the commit history
around `c737244`; it is not a phase decision and has no dedicated doc).
Remaining pending items: IntegratedML (blocked, VR-003), submission
time/timezone and interpretation of the bonus ceiling (both `VERIFY_REQUIRED`
still open, dependent on the contest organizers), and Phase 5 (hardening,
formal tests, video recording, article) — scope defined in
`06_PHASE_5_HARDENING_TESTS_DEMO.md`, execution not yet started. Multi-model
(bonus) **closed 13/09/2026**: second provider Groq integrated in
`Guardian.UI.RAGAltPage` and tested live end to end (see
`04_PHASE_3_RAG_ASSISTANT.md` §3.1.1) — the Gemini free tier remained
unstable in earlier tests (several real timeouts/429/503), one more reason to
have a second real provider, not just a menu skeleton.
