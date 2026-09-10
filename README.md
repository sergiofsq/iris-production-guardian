# IRIS Production Guardian

A copilot for InterSystems IRIS administrators and developers: observe a
Production, investigate incidents with evidence, and query documentation
with context. Built for the **InterSystems PT Developer Community 2026
Programming Contest**.

> **Status: work in progress.** This README reflects what is actually
> implemented and verified today, not the full target scope. See
> [Project status](#project-status) below for an honest breakdown.

## What this is

Three planned modules, built on InterSystems IRIS only:

- **Production Monitor** — observe a Production's components (Services,
  Processes, Operations), queues, errors and timelines.
- **AI Incident Investigator** — given an incident, component and time
  window, gather metrics/events/documentation and produce a
  hypothesis-with-evidence summary (read-only; no automated remediation).
- **RAG Assistant** — ingest authorized documentation/runbooks and answer
  questions with traceable citations, abstaining when unsupported.

## Technology constraints (non-negotiable for this project)

- **InterSystems ObjectScript (COS) first** for business logic,
  interoperability, and orchestration.
- **InterSystems IRIS is the only database.** No PostgreSQL, SQLite,
  MongoDB, Redis, or external vector database — native IRIS Vector Search
  and Foreign Tables are used instead where needed.
- **Python only where COS cannot do the job**, with the limitation
  documented case by case. No Python for convenience or contest points.
- Web UI: plain HTML/CSS plus the minimum browser JS needed for
  presentation; business rules stay in the COS backend.

Full rationale in `docs/planejamento/IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`
(Portuguese, internal planning context).

## Project status

| Area | Status |
|---|---|
| IRIS environment (Docker, Community Edition, ARM64) | ✅ Working, documented, reproducible |
| Vector Search (native IRIS) | ✅ Confirmed available, no extra license |
| Foreign Table | ✅ Confirmed available, no extra license |
| IntegratedML (AutoML provider) | ❌ Confirmed **unavailable** on this image (missing proprietary `iris_automl` Python package) — out of MVP scope, see `docs/planejamento/07_SCORECARD_EVIDENCIAS.md` |
| Production (Service → Process → Operation) | ✅ Implemented and tested end-to-end with a real message, including a controlled failure + recovery scenario |
| Production Monitor UI | 🚧 Not started |
| AI Incident Investigator | 🚧 Not started |
| RAG Assistant | 🚧 Not started |
| Business Rules engine | 🚧 Not started (routing is currently plain code) |

Detailed, dated evidence for every item above lives in
`docs/planejamento/07_SCORECARD_EVIDENCIAS.md` and the phase documents
(`docs/planejamento/00_MASTER_PLAN.md` onward). Nothing in this README is
claimed without a corresponding test that was actually run.

## Architecture (proposed, validated incrementally)

```text
Web UI: Monitor | Investigator | RAG Assistant
                       |
Application layer: queries, investigation, retrieval
                       |
InterSystems IRIS: persistence and interoperability
      |                |                    |
COS Production      Events/metrics     Documents/indexes
      |
Service -> Process -> Operation
      |
Controlled demo destination
```

## Repository layout

```
src/Guardian/             COS source (Production, hosts, messages)
assets/                   Visual identity (logo, CSS tokens)
docs/experiments/         Reproducible step-by-step experiment scripts
                           (used to record the contest demo video)
docs/planejamento/        Phase tracking, decisions, timeline, evidence
                           scorecard (Portuguese) — 00_MASTER_PLAN.md
                           onward, plus the conversation-context doc
```

## Running it locally

### 1. Start InterSystems IRIS Community Edition in Docker

```sh
docker volume create iris-guardian-data

# first run only: the named volume is root-owned by default, but IRIS
# runs as irisowner (uid/gid 51773) and refuses to start otherwise
docker run --rm --user root --entrypoint chown \
  -v iris-guardian-data:/durable \
  intersystems/iris-community:latest-cd \
  -R 51773:51773 /durable

docker run -d --name iris-guardian \
  -p 51972:1972 -p 53773:52773 \
  -e ISC_DATA_DIRECTORY=/durable \
  -v iris-guardian-data:/durable \
  intersystems/iris-community:latest-cd
```

> Do **not** use the `intersystems/iris-community-arm64` image — it is
> unmaintained and its embedded Community license has expired.

### 2. Create the namespace and an admin user

Via the Management Portal (`http://localhost:53773/csp/sys/UtilHome.csp`,
log in as `_SYSTEM`):

1. Create a dedicated administrative user (System Administration → Users).
2. System Administration → Configuration → Namespaces → New Namespace:
   name `GUARDIAN`, new database `GUARDIANDB` for both Globals and
   Routines, **interoperability enabled**.

(Step-by-step with screenshots-worthy detail: `docs/planejamento/01_FASE_0_SETUP_ARQUITETURA.md`.)

### 3. Load and start the Production

Compile the classes under `src/Guardian/` into the `GUARDIAN` namespace
(e.g. via VS Code + the InterSystems ObjectScript extension pointed at
`localhost:53773`, namespace `GUARDIAN`), then:

```objectscript
Do ##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")
```

Or start it from Interoperability → Configure → Production in the portal.

### 4. Serve the static assets (logo, CSS) used by the Monitor/RAG pages

The `GUARDIAN` CSP web application serves static files straight from its
physical directory inside the container. Copy them in once per fresh
container (they live in the named volume, so this survives restarts, but
not a brand-new `docker volume create`):

```sh
docker cp assets/iris-guardian-logo-header.png iris-guardian:/durable/csp/guardian/iris-guardian-logo-header.png
docker exec iris-guardian mkdir -p /durable/csp/guardian/assets/css
docker cp assets/css/iris-guardian-theme.css iris-guardian:/durable/csp/guardian/assets/css/iris-guardian-theme.css
```

### 5. Reproduce the failure/recovery demo

Follow `docs/experiments/01_falha_recuperacao_producao.md` step by step —
it drives the Production with real file drops, breaks the output
destination, and shows both automatic recovery (new traffic) and manual
recovery (`Ens.MessageHeader.ResendMessage`) for the message that failed
during the outage.

## AI-assisted development

This project is being built with AI coding assistance (Claude Code). The
methodology — prompts, decisions, corrections of incorrect AI suggestions,
and validation steps — is tracked as part of the contest's evaluation
criteria and will be detailed in the community article accompanying the
submission.

## License

Not yet decided.
