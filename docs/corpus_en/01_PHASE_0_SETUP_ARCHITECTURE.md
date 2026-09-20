# Phase 0 — Setup and Architecture

> Consolidates the real inventory of the environment, the architecture
> decisions taken and the state of the technical pending items up to
> **09/09/2026**. The detail of the technical evidence of each test is in
> `07_EVIDENCE_SCORECARD.md`; this document does not repeat the commands, it
> only summarizes the result and the decision. The no-hallucination rules and
> the `VERIFY_REQUIRED` register follow `IRIS-Production-Guardian-
> CONVERSATION-CONTEXT.md` (section 4).

## 1. Environment inventory (observed, not assumed)

| Item | Confirmed value |
|---|---|
| Host | macOS 26.6.2, arm64 (Apple Silicon) |
| Docker | Docker Desktop, local engine (`docker info` responds) |
| IRIS image | `intersystems/iris-community:latest-cd` (multi-arch, build of 22/07/2026) |
| IRIS version | `IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.2 (Build 221U)`, confirmed via `$ZVERSION` |
| Edition | Community |
| Embedded Python | 3.12.3 (Embedded Python, `%SYS.Python`) |

**Finding, not assumed:** the `intersystems/iris-community-arm64` repository
(the one without multi-arch) has been abandoned since mid-2025; its embedded
Community license has expired and the instance refuses to start. Do not use
that repository in this project — use `intersystems/iris-community:latest-cd`.

## 2. Container and persistence

- Container: `iris-guardian`.
- Published ports: `51972` (SuperServer, host→1972 in the container), `53773`
  (webserver/Management Portal, host→52773 in the container) — remapped on
  10/09/2026 to avoid colliding with the Cache/Ensemble/IRIS already in use on
  another VM (`1972`, `57772`, `57773`).
- Named volume `iris-guardian-data`, mounted at `/durable`, with
  `ISC_DATA_DIRECTORY=/durable` → data survives `docker rm`.
- **Finding, not assumed:** a freshly created named Docker volume belongs to
  `root`; the instance runs as `irisowner` (uid/gid `51773`) and fails to start
  until the volume is adjusted with `chown -R 51773:51773 /durable` before the
  first start. Confirmed after the adjustment.
- Layout confirmed under `/durable/mgr/`: each database lives in its own
  subfolder (`/durable/mgr/user/IRIS.DAT` for the `USER` namespace,
  `/durable/mgr/IRIS.DAT` at the root for `%SYS`). This convention was applied
  to the project database (section 3).

## 3. Project namespace and database

Created on 09/09/2026 via the Management Portal (`System > Configuration >
Namespaces > New Namespace`):

| Item | Value |
|---|---|
| Namespace | `GUARDIAN` |
| Database (Globals and Routines) | `GUARDIANDB`, a single database for both — same pattern as the `USER` namespace |
| Database directory | `/durable/mgr/guardian/` (dedicated subfolder, outside the root of `/durable/mgr/`) |
| Interoperability (Productions) | Enabled |

Verification by command line (not just by the portal screen):

```
##class(Config.Namespaces).Exists("GUARDIAN")        → 1
##class(Config.Databases).Exists("GUARDIANDB")        → 1
##class(%EnsembleMgr).IsEnsembleNamespace("GUARDIAN") → 1
```

The `GUARDIAN` namespace is the project's working namespace from now on. The
VR-001/002/003 tests (section 4) were run before this namespace was created,
in the `USER` namespace, and their test artifacts were already removed from
there — no residue is left in `USER` or in `GUARDIAN`.

## 4. Users and credentials

- The `demo` user expected from the container's `IRIS_USERNAME`/`IRIS_PASSWORD`
  environment variables **was not created** that way in this image — a
  finding, not assumed, diverging from the initial expectation.
- Initial administrative login done as `_SYSTEM`; the default password was
  changed by the owner.
- A dedicated project user (role `%All`) was created for ongoing use in the
  Management Portal and in development. The credential is not documented in
  this file nor in any versioned file, following the rule of not including
  secrets in Git (context section 10). Kept only in local memory of the
  agent/owner; migrate to an appropriate secret mechanism (non-versioned `.env`
  + `.gitignore`) before any automation that needs it.

## 5. VERIFY_REQUIRED test results (Phase 0)

Full detail, commands and evidence in `07_EVIDENCE_SCORECARD.md`.

| ID | Feature | State | Result |
|---|---|---|---|
| VR-001 | Vector Search (`VECTOR`, `TO_VECTOR`, `VECTOR_COSINE`) | confirmed | Works in the Community Edition, with no additional license. Enables native vector search for the RAG Assistant. |
| VR-002 | Foreign Table (`CREATE FOREIGN SERVER`/`FOREIGN TABLE`) | confirmed | Works in the Community Edition, with no additional license. Enables the Foreign Table bonus (+1). |
| VR-003 | IntegratedML (provider `%AutoML`) | confirmed — blocked | `CREATE MODEL` works (SQL/COS layer ok); `TRAIN MODEL` fails (`SQLCODE -186`). Root cause: the proprietary Python package `iris_automl` is absent from the Community ARM64 image and is not available on public PyPI. Bonus (+3) out of MVP scope until there is a decision from the owner or an official source for the package. |

## 6. Recorded architecture decisions

1. **COS/ObjectScript first** for business logic, interoperability and
   orchestration — per the mandatory premise (context section 1.1). No
   exception applied so far.
2. **Persistence exclusively in InterSystems IRIS** — no external database was
   introduced; native Vector Search covers the RAG's vector-search need without
   depending on an external vector database (VR-001).
3. **WSGI and PyProd dropped as bonuses to pursue** — they are not a technical
   pending item, they are a structural conflict with the COS-first premise
   (WSGI is a Python interface by definition; PyProd hosts hosts written in
   Python). Owner's decision already recorded in the scorecard.
4. **IntegratedML out of MVP scope** (VR-003) — alternative providers (`H2O`
   requires an external server, conflicting with "no external dependency";
   `PMML` only imports a model already trained outside IRIS) do not meet the
   goal of training/predicting inside IRIS.
5. **Own visual identity** — logo without the official InterSystems wordmark
   (risk of suggesting unauthorized endorsement), palette extracted from the
   own art, tokens in `assets/css/iris-guardian-theme.css`.
6. **Dedicated namespace/database for the project** (`GUARDIAN`/`GUARDIANDB`),
   with interoperability enabled since creation, to support the COS Production
   of Phase 1.

## 7. Identified risks

- **IntegratedML blocked** (VR-003): if the owner wants to claim that bonus, it
  will be necessary to find an official and lawful source of the `iris_automl`
  package for this image/edition, or change image/edition — not yet evaluated.
- **Schedule**: the 21/09/2026 schedule (context section 7) has no large
  slack; bonus items with uncertain dependencies (multi-model, hybrid, public
  API) must receive a short proof of feasibility before a larger investment.
- **Local credentials**: the `guardian` user was created without a formal
  secret-management mechanism (`.env`/`.gitignore`) in the repository yet —
  resolve before any automation script that depends on it.

## 8. Still-open pending items (not tested)

Inherited from the initial list of the context (section 4) and still without a
test/decision:

- Metrics/queues/logs interfaces actually available for the Monitor.
- Business Rules (real routing, not disguised conditionals).
- Multi-model — real forms of access, by type.
- Hybrid search (lexical + vector).
- Access to a suitable public API for the corresponding bonus.
- AI models and keys (embeddings/generation provider) — owner's decision
  pending (cost, access, data).
- Official submission cut-off time/timezone (21/09/2026) — do not assume
  23:59.
- Interpretation of the bonus/multi-model ceiling by the contest organizers.

## 9. Phase 0 exit criteria

- [x] Real IRIS environment inventoried and documented.
- [x] Durable container/volume validated and reproducible (`chown` step
      documented).
- [x] Project namespace and database created and verified by command.
- [x] VR-001, VR-002, VR-003 closed with evidence.
- [ ] Multi-model, hybrid search and public API — minimum proof of feasibility
      pending.
- [ ] Initial structure of the web interface (shell of the three modules) —
      not yet started.

**Phase 0 state: in progress.** Infrastructure and VRs critical to the MVP
closed; bonus items with uncertain dependencies remain open and do not block
the start of Phase 1 (COS Production), which can start in parallel.
