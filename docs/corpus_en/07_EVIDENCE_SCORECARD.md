# Pending register (VERIFY_REQUIRED) — Phase 0

> This file is the single pending register foreseen in
> `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` (section 4, "Mandatory use
> of VERIFY_REQUIRED"). Each item below is only closed with observed evidence,
> not by reading documentation in isolation.

## Environment validated on 09/09/2026

- Host: macOS 26.6.2, arm64 (Apple Silicon), Docker 29.4.0.
- Image used: `intersystems/iris-community:latest-cd` (multi-arch, build
  22/07/2026) → `IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.2
  (Build 221U)`, confirmed via `$zversion` inside the container.
- **Finding, not assumed**: the `intersystems/iris-community-arm64` repository
  (the one without multi-arch) has been abandoned since mid-2025. Its embedded
  Community license has expired and the instance refuses to start (`Invalid
  Community Edition license, may have exceeded core limit`). Do not use that
  repository in this project.
- Container: `iris-guardian`, ports `51972` (SuperServer, host→1972 in the
  container) and `53773` (webserver, host→52773 in the container) — changed on
  10/09/2026 to avoid colliding with the Cache/Ensemble/IRIS of another VM
  (`1972`, `57772`, `57773`), named volume `iris-guardian-data` mounted at
  `/durable` with `ISC_DATA_DIRECTORY=/durable` (durable %SYS — data survives
  `docker rm`). Test user: `demo`.
- **Finding, not assumed**: a freshly created named Docker volume belongs to
  `root` by default; the IRIS instance runs as `irisowner` (uid/gid `51773`) and
  fails to start (`Target exists but is not writeable: /durable/`) until the
  volume is adjusted with `docker run --rm --user root --entrypoint chown -v
  <volume>:/durable intersystems/iris-community:latest-cd -R 51773:51773
  /durable` before the first start. Confirmed after the adjustment:
  `/durable/mgr/IRIS.DAT` and the other database files present in the volume,
  owned by `irisowner`.

## VR-001 — Vector Search in the Community Edition

- Question: are the `VECTOR` type and the similarity functions (`TO_VECTOR`,
  `VECTOR_COSINE`) available in the Community Edition, with no additional
  license?
- Evidence required: minimal test in the real environment.
- How verified: via `%SQL.Statement` in the `USER` namespace:
  - `CREATE TABLE VecTest (id INT, v VECTOR(DOUBLE, 3))` → executed
    successfully.
  - `SELECT TO_VECTOR('1,2,3', DOUBLE)` → returned a real vector.
  - `SELECT VECTOR_COSINE(TO_VECTOR('1,2,3',DOUBLE), TO_VECTOR('1,2,4',DOUBLE))`
    → returned `0.99146013398366727997`.
- State: **confirmed**. No license restriction observed.
- Impact: enables native vector search in IRIS for the RAG Assistant, without
  depending on an external vector database.

## VR-002 — Foreign Table in the Community Edition

- Question: do `CREATE FOREIGN SERVER` / `CREATE FOREIGN TABLE` require a paid
  edition (license feature no. 27 appears in the `%SYSTEM.License`
  documentation, but there was no confirmation for the Community Edition)?
- Evidence required: minimal test in the real environment.
- How verified: via `%SQL.Statement` in the `USER` namespace:
  - `CREATE FOREIGN SERVER TestFS2 FOREIGN DATA WRAPPER JDBC CONNECTION
    'dummyconn'` → prepared successfully (the `Postgres` wrapper, tested first,
    failed because of an invalid name, not because of a license).
  - `CREATE FOREIGN TABLE TestFT (id INT, name VARCHAR(50)) SERVER TestFS2` →
    success status (`1`).
- State: **confirmed**. No license restriction observed.
- Impact: enables the Foreign Table bonus (+1) without an edition exception.

## Visual identity decision — 09/09/2026

- Source: `ImagemMatriz.png` (provided by the owner) contained the "IRIS
  Guardian" product art and, in the footer, the official registered wordmark
  "InterSystems® | DATA | INTELLIGENCE | ACTION".
- Risk identified: using the official InterSystems wordmark inside a community
  submission app may suggest unauthorized official endorsement.
- Owner's decision: keep only the product's own art (shield + "IRIS Guardian" +
  tagline + icons), removing the footer with the official wordmark.
- Implemented: `assets/iris-guardian-logo.png` (a crop of `ImagemMatriz.png`,
  without the InterSystems® footer) is the logo to use in the application pages.
  The original `ImagemMatriz.png` stays in the repository only as
  source/history and must not be used in public pages.
- Brand palette extracted by pixel sampling of the art itself (not of
  InterSystems assets) and recorded as CSS tokens in
  `assets/css/iris-guardian-theme.css`: navy `#0a1965`/`#102f8b`, teal
  `#0fd1c4`/`#01989c`, accent purple `#3a2fb5`. Typography uses a system font
  stack, not InterSystems' proprietary font.

## VR-003 — IntegratedML (AutoML provider) in the Community Edition

- Question: do `CREATE MODEL` / `TRAIN MODEL` / `PREDICT` (IntegratedML, default
  provider `%AutoML`) work on this instance without an additional license?
- Evidence required: minimal test in the real environment, with labeled
  synthetic data.
- How verified: via `%SQL.Statement` in the `USER` namespace, table `MLTest` (32
  synthetic rows, 2 numeric features + `label` A/B):
  - `CREATE TABLE MLTest (...)` → executed successfully.
  - `DROP MODEL IF EXISTS MLTestModel` / `CREATE MODEL MLTestModel PREDICTING
    (label) FROM MLTest` → `%SQLCODE 0`, success (the SQL/COS layer of
    IntegratedML works).
  - `TRAIN MODEL MLTestModel` → `%SQLCODE -186`, message `%ML Provider 'AutoML'
    is not available on this instance`.
  - Root cause confirmed (not assumed): the class `%ML.AutoML.Provider`
    (`%ImportPackage`) requires the Python modules `iris_automl.automl`, `numpy`
    and `pandas` via Embedded Python (`%SYS.Python`). Inside the container,
    `python3 -c "import iris_automl"` and `import sklearn` / `import pandas` fail
    with `ModuleNotFoundError`. A search across the whole filesystem (`find /
    -iname "*automl*"`) found no file, wheel or requirements related to AutoML
    embedded in the `intersystems/iris-community:latest-cd` image (ARM64,
    2026.2). `pip index versions iris_automl` / `pip download iris_automl`
    confirm the package is not on public PyPI — it is proprietary to InterSystems
    and is not distributed with this image/edition.
- State: **confirmed — blocked in this environment**. It is not an SQL license
  restriction (model creation is accepted); it is the absence of the
  `iris_automl` Python training engine in the Community Edition ARM64 image used.
- Impact: the IntegratedML bonus (+3) is not viable with the current container
  without an official source of the `iris_automl` package (not found publicly).
  Alternative providers (`%H2O` requires an external H2O server — it would
  violate the premise of not introducing external dependencies; `%PMML` imports
  a model already trained outside IRIS, it does not train from the project's
  data) do not meet the goal of training/predicting inside IRIS without an
  external dependency. Record this bonus as **out of MVP scope** until there is
  a decision from the owner or an official source of the package.
- Test artifacts (`MLTest`, `MLTestModel`) removed from the `USER` namespace
  after verification; no residue remains in the environment.

## Bonuses with recorded evidence — Phase 1 (09/09/2026)

Full detail in `02_PHASE_1_PYPROD_INTEROPERABILITY.md`.

### Service, Process and Operation (+1)

- Proof: Production `Guardian.Production.GuardianProduction` in the `GUARDIAN`
  namespace, with one host of each type
  (`Guardian.Service.FileIncidentService`,
  `Guardian.Process.IncidentRouterProcess`,
  `Guardian.Operation.FileOutputOperation`).
- Evidence: a real `Guardian.Messages.IncidentEvent` message (`INC-001`) crossed
  the three hosts, confirmed by (a) the output file `out/incident_INC-001.txt`
  with the `ProcessedBy`/`ProcessedAt` fields filled in by the Process, and (b)
  an SQL query on `Ens.MessageHeader` showing the three transitions with
  `Status=9` (completed).
- State: **confirmed**.

### Adapter on a host (+1)

- Proof: `Guardian.Service.FileIncidentService` uses
  `EnsLib.File.InboundAdapter` (reads `/durable/guardian/in`, archives to
  `/durable/guardian/archive`); `Guardian.Operation.FileOutputOperation` uses
  `EnsLib.File.OutboundAdapter` (writes to `/durable/guardian/out`). Both are
  adapters natively supported by IRIS, with no external dependency.
- Evidence: the end-to-end test described above — a file dropped in `in/`
  correctly produced the corresponding file in `out/` via the two adapters.
- State: **confirmed**.

### Controlled failure and recovery (evidence for the Monitor's "Proposed acceptance")

- Proof: the Operation's destination (`/durable/guardian/out`) made unavailable
  (`chmod 555`); incident fired; real error captured in
  `Ens.MessageHeader.ErrorStatus` (`ERROR #5005: Cannot open file...`,
  `<Ens>ErrFailureTimeout` after 15s). Destination fixed; new traffic recovers
  automatically; affected message recovered manually via
  `Ens.MessageHeader.ResendMessage`.
- Evidence: reproducible script validated twice from scratch in
  `docs/experiments/01_falha_recuperacao_producao.md`; full detail in
  `02_PHASE_1_PYPROD_INTEROPERABILITY.md` §5.
- State: **confirmed**. Covers the Production Monitor's "Proposed acceptance"
  (context, section 2): failure traceable to the original event, recovery
  visible (automatic and manual).

## RAG Assistant (09/09/2026)

Full detail in `04_PHASE_3_RAG_ASSISTANT.md`.

### Functional RAG (main item, 5 points)

- Proof: ingestion (`Guardian.RAG.Ingestion`, 79 fragments from 5 real project
  documents), vector retrieval (`Guardian.RAG.Query`, `VECTOR_COSINE` + `TOP
  5`), generation with source citation (`Guardian.RAG.GeminiClient`), abstention
  when similarity is low, query page (`Guardian.UI.RAGPage`).
- Evidence: a relevant question ("why doesn't IntegratedML work") answered
  correctly with a citation of the right source (similarity 0.653); an
  irrelevant question ("chocolate cake recipe") correctly abstained (similarity
  0.518, below the 0.58 threshold); a real API unavailability (Gemini returned
  `503`) handled without taking the application down.
- State: **confirmed**.

### Chunking/embedding justification (+2)

- Proof: embedding dimension (768, truncated from the default 3072 via Gemini's
  Matryoshka representation) and chunking strategy (paragraph up to 800
  characters, 150 overlap) documented with explicit reasoning in
  `04_PHASE_3_RAG_ASSISTANT.md` sections 3 and 3.2.
- Quantitative reinforcement (10/09/2026): formal A/B comparison against naive
  fixed-window chunking (`Guardian.RAG.Eval.RunChunkingComparison`, 7 questions,
  same text for both strategies) — paragraph won on average similarity in all 7
  questions (0.709 vs 0.684), without exception. Both hit the right document in
  100% of cases. See `04_PHASE_3_RAG_ASSISTANT.md` §7.2.
- State: **confirmed**, now with quantitative evidence beyond the reasoning.

### RAG pipeline clarity (+2)

- Proof: pipeline documented end to end (ingestion → chunking → embedding →
  vector storage → retrieval → generation → citation → abstention), with a
  textual diagram and each step tested individually with real evidence (not just
  described).
- State: **confirmed**.

### Hybrid search — lexical + vector (+3) — 10/09/2026

- Proof: native full-text index `%iFind.Index.Basic` (`idxChunkTextFind`) on
  `Guardian_RAG.Chunk.ChunkText`, created in `Guardian.RAG.Schema.Setup`; fused
  with the existing vector search via Reciprocal Rank Fusion (`k=60`) in
  `Guardian.RAG.Query.Ask`, a pool of up to 15 candidates from each search,
  final TopK 5.
- Evidence: a question with an exact error code ("What does error #5005 mean in
  the failure scenario?") retrieved and correctly cited the right chunk (best
  similarity 0.677, 5 sources); an irrelevant question ("chocolate cake recipe")
  still correctly abstained (similarity 0.521, below the 0.58 threshold) —
  confirms that the hybrid fusion did not change the abstention calibration
  already validated, since the gate uses only pure vector similarity.
- Finding recorded (not hidden): iFind's native ranking function
  (`%iFind.Rank`) did not accept the syntax tested live (`Field
  'IDXCHUNKTEXTFIND' not found`); instead of inventing an uncalculated rank
  position, a lexical match adds a fixed bonus equivalent to rank 1 in the fusion
  — an honest simplification, documented in `04_PHASE_3_RAG_ASSISTANT.md` §6.
- State: **confirmed**.

## AI Incident Investigator (10/09/2026)

Full detail in `05_PHASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md`.

### Functional Investigator (main item)

- Proof: `Guardian.Investigator.EvidenceCollector` gathers real health (reuses
  `Guardian.Monitor.StatusCollector`), real events from `Ens.MessageHeader` (with
  the error converted to readable text via `$System.Status.GetErrorText`) and
  relevant documentation (reuses the RAG's hybrid search via
  `Guardian.RAG.Query.Retrieve`); `Guardian.Investigator.Analyzer` generates a
  summary/hypotheses/gaps/next steps separating observation from hypothesis,
  with no invented confidence percentage; `Guardian.UI.InvestigatorPage`
  presents everything and persists the investigation in
  `Guardian_Investigator.Investigation`.
- Evidence: a real investigation of `Guardian.Operation.FileOutputOperation`
  against the history of the Phase 1 failure/recovery experiment — 20 real events
  retrieved (including the 3 `#5005` error episodes), the analysis correctly
  separated observations from hypotheses, and flagged as a **gap** (not as an
  invented fact) the discrepancy between `unavailable` health and `recent
  errors=0`. Investigation confirmed persisted by a direct SQL query.
- State: **confirmed**.

## Business Rules — real rule-based routing (+2, 10/09/2026)

Full detail in `02_PHASE_1_PYPROD_INTEROPERABILITY.md` §6.

- Proof: `Guardian.Rule.IncidentRoutingRule` (`Extends Ens.Rule.Definition`)
  decides the destination config name from the `Severity` of
  `Guardian.Messages.IncidentEvent`; `Guardian.Process.IncidentRouterProcess`
  calls `##class(Ens.Rule.Definition).EvaluateRules(...)` instead of using a fixed
  `TargetConfigName`. A second Operation
  (`Guardian.Operation.PriorityOutputOperation`) was created for the second
  possible destination.
- Evidence: `INC-101` (`HIGH`) → `out_priority/`, `INC-102` (`LOW`) → `out/`,
  confirmed by file and by `Ens.MessageHeader` (Process routing dynamically to
  different operations in the same run). Then the rule condition was changed to
  include `MEDIUM` and recompiled — without touching `IncidentRouterProcess` or
  the Production — and `INC-103` (`MEDIUM`), which would previously land in
  `out/`, started landing in `out_priority/`. Direct proof of the criterion
  "change a condition in a test and observe the result".
- State: **confirmed**.

## Public API access — PublicHealth (+2, 11/09/2026)

Full detail in commit `67b00b9`; no dedicated phase doc (a bonus implemented
after Phase 4, outside the window of any existing phase file).

- Proof: `Guardian.Production.PublicHealthProduction` does real polling of
  `disease.sh/v3/covid-19/all` (a public API with no key/authentication) via
  `Guardian.Adapter.PublicHealthPollAdapter` — a custom adapter that extends
  `Ens.InboundAdapter`, self-limiting (the API does not publish a rate-limit
  header, so the minimum interval between real calls is imposed by the adapter
  itself, not by the framework). Each real poll (success or failure) generates a
  `Guardian.Messages.PublicHealthSnapshot` message to
  `Guardian.Operation.PublicHealthOutputOperation`, sole owner of the
  `Guardian_PublicHealth.Snapshot` table: it writes a "live" row on success, or
  falls back to the last known real value labeled as cache (with the age
  computed from the original fetch) on failure, or marks honest unavailability
  if there is no cache yet — it never invents a number.
- Evidence: a real poll against `disease.sh` wrote a live row; a forced-failure
  test (endpoint changed to an invalid path, a real HTTP 404) correctly
  triggered the cache fallback with the right age and the HTTP status that caused
  the drop, labeled as such; the correct endpoint restored afterwards and
  confirmed writing live again.
- State: **confirmed**.

## Multi-model (bonus) — Groq (13/09/2026)

Full detail in `04_PHASE_3_RAG_ASSISTANT.md` §3.1.1.

- Proof: a second AI provider, Groq (`Guardian.RAG.GroqClient`, model
  `openai/gpt-oss-120b`), integrated in `Guardian.UI.RAGAltPage`; generation
  changes provider while retrieval and embeddings stay the same.
- Evidence: tested live end to end through the page itself, with a real answer
  from Groq citing the sources.
- State: **confirmed**.

## Items still open (not tested in this round)

- WSGI and PyProd: not a technical pending item, they are a structural conflict
  with the "COS first" premise (context section 1.1) — WSGI is by definition a
  Python interface; PyProd hosts hosts written in Python. Owner's decision
  recorded: do not pursue these two bonuses, keep everything in COS.
- IntegratedML: blocked (VR-003), out of MVP scope.
