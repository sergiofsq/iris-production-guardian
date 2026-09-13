# IRIS Production Guardian

A copilot for InterSystems IRIS administrators and developers: observe a
Production, investigate incidents with evidence, and query documentation
with context. Built for the **InterSystems PT Developer Community 2026
Programming Contest**.

> **Status: work in progress.** This README reflects what is actually
> implemented and verified today, not the full target scope. See
> [Project status](#project-status) below for an honest breakdown.

## What this is

Three core modules, built on InterSystems IRIS only:

- **Production Monitor** — observe a Production's components (Services,
  Processes, Operations), queues, errors and timelines.
- **AI Incident Investigator** — given an incident, component and time
  window, gather metrics/events/documentation and produce a
  hypothesis-with-evidence summary (read-only; no automated remediation).
- **RAG Assistant** — ingest authorized documentation/runbooks and answer
  questions with traceable citations, abstaining when unsupported. Two
  independent generation providers are wired in (menu: "RAG Assistant
  (Gemini)" and "RAG Assistant (Groq)") — retrieval/embeddings stay on
  Gemini, only the answer-generation model swaps.

Plus bonus scope, also implemented and tested (not just started):

- **Business Rules routing** — `Guardian.Rule.IncidentRoutingRule`
  (`Ens.Rule.Definition`) decides the incident's destination Operation by
  severity, editable visually in the portal without recompiling.
- **Hybrid search** — RAG retrieval fuses vector similarity with iFind
  lexical search (Reciprocal Rank Fusion) instead of vector-only.
- **PublicHealth bonus Production** — a second, independent Production
  (`Guardian.Production.PublicHealthProduction`) polling a real public
  API (`disease.sh`), demonstrating the cache/unavailable-fallback
  pattern without ever inventing data.

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
| Production (Service → Process → Operation) | ✅ Implemented and tested end-to-end with a real message, including a controlled failure + recovery scenario, and severity-based routing (Business Rules, below) |
| Production Monitor UI | ✅ Implemented and tested — live host health, queues, error counts, timeline |
| AI Incident Investigator | ✅ Implemented and tested — real evidence (metrics/events/docs) + AI analysis, hypothesis separated from observation |
| RAG Assistant | ✅ Implemented and tested — hybrid retrieval (vector + lexical), generation with citation, calibrated abstention. Two providers wired in: Gemini (default) and Groq (second menu entry, bonus "multimodelo") |
| Business Rules engine | ✅ Implemented and tested — `Guardian.Rule.IncidentRoutingRule` (`Ens.Rule.Definition`) routes by severity, editable in the portal without recompiling |

Detailed, dated evidence for every item above lives in
`docs/planejamento/07_SCORECARD_EVIDENCIAS.md` and the phase documents
(`docs/planejamento/00_MASTER_PLAN.md` onward). Nothing in this README is
claimed without a corresponding test that was actually run. What's still
open: Fase 5 hardening items (a full clean-install pass is below; formal
video/community article still pending) and two `VERIFY_REQUIRED` items
that depend on the contest organizers (submission deadline/timezone,
bonus cap interpretation).

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
src/Guardian/             COS source, one subpackage per concern:
  Production/               the 2 Productions (main + PublicHealth bonus)
  Service/ Process/          Business Service / Process (COS, not BPL)
  Operation/ Adapter/        Business Operations + a custom InboundAdapter
  Rule/                      Business Rules (severity routing, bonus)
  Messages/                  Ens.Request/Response message classes
  Monitor/ Investigator/     Status collection, evidence + AI analysis
  RAG/                       Ingestion, hybrid retrieval, generation
                              (Guardian.RAG.GeminiClient/GroqClient)
  UI/                        %CSP.Page classes (Monitor/Investigator/RAG),
                              i18n, shared sidebar
  API/                       REST-ish JSON endpoint for Monitor status
assets/                   Visual identity (logos, CSS tokens, spinner)
docs/experiments/         Reproducible step-by-step experiment scripts
                           (used to record the contest demo video)
docs/planejamento/        Phase tracking, decisions, timeline, evidence
                           scorecard (Portuguese) — 00_MASTER_PLAN.md
                           onward, plus the conversation-context doc
entregaveis/               Contest deliverables: user manuals (PT/EN),
                           OSM support-model doc, and Prompts/ (the
                           prompt sequence used to build this app with
                           AI assistance, for the methodology criterion)
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

### 2. Create the namespace, database and an admin user

Via the Management Portal (`http://localhost:53773/csp/sys/UtilHome.csp`,
log in as `_SYSTEM` — first login forces a password change):

1. System Administration → Configuration → Namespaces → New Namespace:
   name `GUARDIAN`, new database `GUARDIANDB` for both Globals and
   Routines, **interoperability enabled** (checkbox in the wizard).
2. Create a dedicated administrative user (System Administration →
   Users) with role `%All` — this repo's docs/scripts assume `guardian`/
   `guardian`; pick your own if you prefer, just adjust anything that
   references it (also `.vscode/settings.json`'s `username`).

Equivalent, scriptable version of both (run from `iris session IRIS -U
%SYS`, no portal needed) — useful for a throwaway/CI instance:

```objectscript
Set dbprops("Globals")="GUARDIANDB"
Set dbprops("Routines")="GUARDIANDB"
Do ##class(Config.Databases).Create("GUARDIANDB",.dbprops)

Set nsprops("Globals")="GUARDIANDB"
Set nsprops("Routines")="GUARDIANDB"
Do ##class(Config.Namespaces).Create("GUARDIAN",.nsprops)

;; "interoperability enabled" is this one property - not obvious from
;; the portal wizard's checkbox alone, took a live trial to confirm
Set iprops("Interop")=1
Do ##class(Config.Namespaces).Modify("GUARDIAN",.iprops)

Do ##class(Security.Users).Create("guardian","%All","guardian","Guardian Admin","GUARDIAN","",,0,1)
```

A CSP web application at `/csp/guardian/` (physical path
`/durable/csp/guardian/`) is created automatically as part of the
namespace — no separate step needed for that part.

(Step-by-step with screenshots-worthy detail: `docs/planejamento/01_FASE_0_SETUP_ARQUITETURA.md`.)

### 3. Load the classes and create the SQL tables

Compile the classes under `src/Guardian/` into the `GUARDIAN` namespace
(e.g. via VS Code + the InterSystems ObjectScript extension pointed at
`localhost:53773`, namespace `GUARDIAN`, or `Do
$system.OBJ.ImportDir("<path>","*.cls","ck",.err,1)` from the terminal).

Compiling the classes does **not** create their SQL tables — four
`Schema` classes build their own tables via `CREATE TABLE` on first use
and must be called once explicitly (idempotent, safe to re-run):

```objectscript
Do ##class(Guardian.RAG.Schema).Setup()
Do ##class(Guardian.Monitor.Schema).Setup()
Do ##class(Guardian.Investigator.Schema).Setup()
Do ##class(Guardian.PublicHealth.Schema).Setup()
```

Skipping this makes every page fail with a `Statement not prepared` SQL
error the first time it touches its table — easy to mistake for a
compile problem, it's really just a missing `.Setup()` call.

### 4. Create the runtime directories and start the Production

The file-based Service/Operations need these directories to exist with
`irisowner` write access before the Production starts (not created
automatically):

```sh
docker exec iris-guardian mkdir -p /durable/guardian/in /durable/guardian/archive /durable/guardian/out /durable/guardian/out_priority
```

Then:

```objectscript
Do ##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")
```

Or start it from Interoperability → Configure → Production in the
portal. If the Production was ever stopped uncleanly (container
restart, crash), `StartProduction` alone throws
`<Ens>ErrProductionNotShutdownCleanly` — call
`Do ##class(Ens.Director).RecoverProduction()` (no arguments) once
first, then retry `StartProduction`.

### 5. Serve the static assets (logo, CSS) used by the Monitor/RAG pages

The `GUARDIAN` CSP web application serves static files straight from its
physical directory inside the container. Copy them in once per fresh
container (they live in the named volume, so this survives restarts, but
not a brand-new `docker volume create`):

```sh
docker cp assets/production-guardian-logo.png iris-guardian:/durable/csp/guardian/production-guardian-logo.png
docker cp assets/production-guardian-logo-dark.png iris-guardian:/durable/csp/guardian/production-guardian-logo-dark.png
docker cp assets/iris-guardian-spinner.png iris-guardian:/durable/csp/guardian/iris-guardian-spinner.png
docker exec iris-guardian mkdir -p /durable/csp/guardian/assets/css
docker cp assets/css/iris-guardian-theme.css iris-guardian:/durable/csp/guardian/assets/css/iris-guardian-theme.css
```

> The private webserver caches 404s per exact URL — if you `curl` a page
> before copying these files and it 404s, a later identical request can
> keep 404ing even after the files exist. Add a cache-busting query
> string (`?cb=1`) or just trust the file is there once `docker exec ...
> ls` confirms it.

### 6. Configure AI provider access (needed for Investigator/RAG)

Outbound HTTPS needs an SSL/TLS config (once per container — the
Community image ships a system CA bundle, no certs to fetch):

```objectscript
Set obj = ##class(Security.SSLConfigs).%New()
Set obj.Name = "PublicHTTPS"
Set obj.Type = 0
Set obj.CAFile = "/etc/ssl/certs/ca-certificates.crt"
Set obj.VerifyPeer = 1
Set obj.Enabled = 1
Do obj.%Save()
```

Then a credential per provider you want working, read at runtime from
`Ens.Config.Credentials` and never written to source (get a free Gemini
key at [aistudio.google.com](https://aistudio.google.com), a free Groq
key at [console.groq.com](https://console.groq.com) — neither needs a
credit card):

```objectscript
Set obj = ##class(Ens.Config.Credentials).%New()
Set obj.SystemName = "Gemini"
Set obj.Username = "gemini-api"
Set obj.Password = "<YOUR_REAL_GEMINI_KEY>"
Do obj.%Save()

Set obj2 = ##class(Ens.Config.Credentials).%New()
Set obj2.SystemName = "Groq"
Set obj2.Username = "groq-api"
Set obj2.Password = "<YOUR_REAL_GROQ_KEY>"
Do obj2.%Save()
```

Without a credential, the Investigator/RAG pages don't crash — they
render normally and show a real "model unavailable" message where the
AI answer would go (verified live). `RAG Assistant (Gemini)` uses the
`Gemini` credential for both retrieval (embeddings) and generation; `RAG
Assistant (Groq)` reuses the same Gemini-embedded corpus for retrieval
and only swaps the `Groq` credential in for generation — it needs
**both** credentials set, not just `Groq`.

### 7. Ingest the RAG corpus

The RAG Assistant answers only from documents you've ingested — nothing
is indexed automatically. Per document:

```objectscript
Do ##class(Guardian.RAG.Ingestion).IngestFile("<path-inside-container>","<source label>","<title>","<version/date>")
```

The corpus actually in use (7 local `docs/planejamento/*.md` files plus
5 external InterSystems Developer Community/docs pages, fetched and
ingested by hand) isn't yet captured as a reproducible script or file
list anywhere in this repo — a real gap, not just a missing README step.
Until that's fixed, ingest at least the local phase docs to get a
working (if smaller) corpus; see `docs/planejamento/04_FASE_3_RAG_ASSISTANT.md`
for the retrieval/abstention design this feeds into.

### 8. Reproduce the failure/recovery demo

Follow `docs/experiments/01_falha_recuperacao_producao.md` step by step —
it drives the Production with real file drops, breaks the output
destination, and shows both automatic recovery (new traffic) and manual
recovery (`Ens.MessageHeader.ResendMessage`) for the message that failed
during the outage.

## AI-assisted development

This project is being built with AI coding assistance (Claude Code). The
methodology — prompts, decisions, corrections of incorrect AI suggestions,
and validation steps — is tracked as part of the contest's evaluation
criteria. The actual prompt sequence (reconstructed by reverse-engineering
from the real code, commits and phase docs where the original prompt
wasn't preserved verbatim) lives in `entregaveis/Prompts/`, one file per
phase/bonus, each with the real errors found and corrected — not an
idealized version without the friction that actually happened. Full
narrative detail in the community article accompanying the submission.

## License

Not yet decided.
