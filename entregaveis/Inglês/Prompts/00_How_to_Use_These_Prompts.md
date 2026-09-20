# Development prompts — IRIS Production Guardian

This folder documents, for the purposes of the contest's "methodology and
prompts" criterion, the sequence of prompts that — given to a coding agent
with access to this repository and to an IRIS Community Edition container
— reproduces the application exactly as it exists today.

**How it was assembled:** by reverse engineering from the real state of
the code (`src/Guardian/`), the commit history and the planning documents
(`docs/planejamento/00_MASTER_PLAN.md` onwards), which already recorded
the date, decision and evidence of each step. The first prompt
(`01_Phase0...md`) is reproduced verbatim from
`docs/planejamento/IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` §12
— it is the real prompt that started the project. The others were
reconstructed in the same style and under the same constraints, from the
final result and the real friction documented in each phase (API errors
fixed, decisions made, pending items closed) — they are not an account of
what happened, they are the equivalent instruction that, given to an agent
from scratch, produces the same result.

## Constraints that accompany EVERY prompt in this sequence

These rules (from
`IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` §1.1 and §4) apply to
every prompt below, even when not repeated in full:

1. **InterSystems ObjectScript (COS) first** for business logic,
   interoperability and orchestration.
2. **InterSystems IRIS is the only database.** No Postgres, SQLite,
   MongoDB, Redis or external vector DB — use IRIS's native Vector Search
   and Foreign Tables.
3. **Python only where COS demonstrably cannot solve the problem**, with
   the limitation documented case by case — never for convenience.
4. **Web UI**: simple HTML/CSS + the minimum of presentation JS; business
   rules stay in the COS backend.
5. **Do not hallucinate**: do not invent classes, methods, endpoints, SQL
   commands, credentials or test results. Confirm against the
   documentation of the real version and, when possible, with a minimal
   test in the environment. Always distinguish planned / implemented /
   tested / demonstrated.
6. **Record pending items as `VERIFY_REQUIRED`** (question, impact,
   evidence needed, owner, status) instead of deciding by assumption —
   ask the owner only when the decision requires their access or choice.
7. **Never send secrets** (passwords, API keys) to the AI model or to
   versioned code — always read them from `Ens.Config.Credentials` at
   runtime.

## Recommended order

| # | File | Deliverable |
|---|---|---|
| 1 | `01_Phase0_Setup_and_Architecture.md` | IRIS environment, namespace, proposed architecture |
| 2 | `02_Phase1_Production_COS.md` | Service → Process → Operation, real message, failure/recovery |
| 3 | `03_Phase2_Production_Monitor.md` | Production health dashboard |
| 4 | `04_Phase3_RAG_Assistant.md` | Ingestion, embeddings, generation with citation, abstention |
| 5 | `05_Phase4_AI_Incident_Investigator.md` | Real evidence + AI analysis |
| 6 | `06_Bonus_Business_Rules_and_Hybrid_Search.md` | Routing by visual rule + hybrid search |
| 7 | `07_Bonus_Public_API_PublicHealth.md` | Second Production consuming a real public API |
| 8 | `08_Bonus_Multimodel_Groq.md` | Second AI provider (Groq) in generation |
| 9 | `09_Phase5_Hardening_Install_Tests.md` | Clean install, formal tests, audit |
| 10 | `10_Phase5b_UX_Loading_and_I18n.md` | Overhaul of the loading indicator and complete i18n coverage |
| 11 | `11_Redesign_Persistent_Sidebar.md` | Persistent sidebar with Production health always visible (applies after items 3-5) |

Each file has: the prompt ready to paste into an agent, the real observed
result (what was fixed, not what was expected), and the link to the
corresponding planning document with the full dated evidence.

**Scope note (09/19/2026):** this folder documents the **application**
(the COS/IRIS system itself). It does not include prompts for the
presentation deliverables generated later (PT/EN manuals, video recording
script, community article) — those are outreach materials about the
project, not steps to rebuild the project.
