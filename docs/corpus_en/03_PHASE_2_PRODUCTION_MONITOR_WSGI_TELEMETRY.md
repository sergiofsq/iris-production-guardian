# Phase 2 — Production Monitor

> File name preserved from the history (`..._WSGI_TELEMETRY.md`). WSGI is not
> used (decision recorded in `01_PHASE_0_SETUP_ARCHITECTURE.md` §6, item 3 —
> conflict with the COS-first premise). Telemetry here means: the real state
> of the Production, obtained by querying IRIS's own `Ens.*` classes directly,
> with no external collector.

## 1. Goal of this phase

Expose, through an interface of its own (outside the Management Portal), the
real state of the hosts of an IRIS Production: healthy, degraded, unavailable
or unknown — with documented rules, not invented ones — and allow a failure to
be traced back to the original event (`Ens.MessageHeader`).

## 2. Verified data sources (none assumed)

| Data | Confirmed real source |
|---|---|
| List of Production hosts, type, enabled/disabled | `Ens_Config.Item` + `Ens_Config.Production` (join on `Item.Production = Prod.ID`) |
| Host type (Service/Process/Operation) | `##class(<ClassName>).%IsA("Ens.BusinessService"/"Ens.BusinessProcess"/"Ens.BusinessOperation")` — not assumed from the class name |
| Pending queue per host | `##class(Ens.Queue).GetCount(pQueueName)` |
| Production state (running/stopped) | `##class(Ens.Director).GetProductionSummary(.info)` |
| Message history, source/target, error | `Ens.MessageHeader` (`SourceConfigName`, `TargetConfigName`, `TimeCreated`, `ErrorStatus`) |
| Per-row error detection | `ErrorStatus <> 1` — tested against real data (2 real errors from the failure experiment, scorecard section 07, were correctly counted) |

**Known limitation (`VERIFY_REQUIRED`):** none of the sources above directly
detects a stuck/dead host job that produced no error message (e.g. a process in
an infinite loop that throws no exception). Phase 2 v1 infers health from
message traffic and the queue, not from the operating system process. Record
this as an explicit limitation in the interface, do not hide it.

## 3. State rules (documented)

Computed per host, in this order:

1. **Unavailable** — the Production is not running (`GetProductionSummary`
   ≠ `"Running"`) **or** the host has `Enabled=0` in `Ens_Config.Item`.
2. **Unknown** — host enabled, Production running, but the host has **never**
   appeared in `Ens.MessageHeader` (neither as source nor as target) since the
   Production exists. Without history, there is no basis to say it is healthy —
   "absence of data is not health" (context, section 2).
3. **Degraded** — host enabled, Production running, with history, and at least
   one of the conditions: (a) pending queue (`Ens.Queue.GetCount`) greater than
   zero; (b) at least one error (`ErrorStatus <> 1`) in the recent-error window
   (`ErrorWindowSeconds`, 15 s) involving that host; (c) unrecovered error —
   the last error involving the host has not yet been followed by a message
   completed successfully (`Status = 9`) on the same source → target path
   (added on 20/09/2026: without it the host returned to `healthy` after 15 s
   even with the destination still broken).
4. **Healthy** — enabled, Production running, with history, no pending queue,
   no recent error and no unrecovered error.

The 15-second window was chosen because it is the same value as the default
`FailureTimeout` observed in `Ens.BusinessOperation` (Phase 1) — it is not an
arbitrary value unrelated to the real system.

## 4. What was implemented

- `Guardian.Monitor.StatusCollector` — single logic for collection and for the
  health rules (section 3), called directly in COS by any consumer. Extracted
  into its own class after the first version (rules directly in the REST class)
  showed that reusing the same logic in the HTML page without duplicating code
  was simpler this way.
- `Guardian.API.MonitorAPI` (`%CSP.REST`) — `GET /status` endpoint in the
  `GUARDIAN` namespace, web application `/api/guardian` (password, no anonymous
  access — same pattern as the `/api/atelier` already used in the project).
  Calls the `StatusCollector` and writes the JSON.
- `Guardian.UI.MonitorPage` (`%CSP.Page`) — page at `/csp/guardian/
  Guardian.UI.MonitorPage.cls` (the namespace's default web application).
  Calls the `StatusCollector` **directly in COS** (no HTTP round trip via
  JavaScript — avoids duplicating authentication between the REST app and the
  CSP app) and renders the three host groups with a color per state. Updates via
  `<meta http-equiv="refresh">` every 10s — no business logic in the browser,
  only static HTML/CSS generated on the server.

### REST application setup command (reproducible)

```objectscript
Set props("NameSpace")="GUARDIAN"
Set props("DispatchClass")="Guardian.API.MonitorAPI"
Set props("Description")="IRIS Production Guardian - Monitor REST API"
Set props("AutheEnabled")=32
Set props("Enabled")=1
Set props("IsNameSpaceDefault")=0
Do ##class(Security.Applications).Create("/api/guardian",.props)
```
(run in the `%SYS` namespace, only once)

## 4.1 Real error found and fixed during development

When compiling `Guardian.API.MonitorAPI` with a `Parameter ERROR_WINDOW_SECONDS
= 900;` referenced as `..#ERROR_WINDOW_SECONDS`, the compiler refused with
`ERROR #5559` (a generic parse error, without pointing to the right line).
Isolated by bisection (several minimal test classes were needed) until
confirmed: **`Parameter` names with an underscore break the parser when
referenced via `..#NAME`** — the `_` is the ObjectScript concatenation
operator, and the reference `..#NAME_REST` is read as `(..#NAME)_(REST)`
instead of a single identifier. Fixed by renaming to `ErrorWindowSeconds`
(PascalCase, no underscore). I did not find this information explicitly
documented before testing — recorded here as empirically verified knowledge,
useful for the AI methodology article (a real example of an error and its
fix).

## 4.2 Second real error: Production state localized by language

Visually confirmed by the owner (screenshot in
`Imagens/Aplicacao/MonitroPage1.jpg`): when opening the page in the browser
(which sends `Accept-Language: pt-BR`), **all hosts appeared as
`unavailable`**, even with the Production running and messages flowing
normally.

Root cause: the rule used `$List(tProdEntry,1) = "Running"` (a string
comparison) from `Ens.Director.GetProductionSummary`. That text is **localized
by IRIS according to the browser language** — in pt-BR it comes as `"Em
execução"`, not `"Running"` — so the comparison always failed outside English.
Via curl (no language header) the bug did not show up, which is why it was not
caught in earlier tests.

Fixed by using `##class(Ens.Director).IsProductionRunning(.pName)` — it returns
a real `%Boolean` (not text) and returns through an output parameter the name
of the production actually running; we compare that name with the expected one
(`..#Production`) so as not to assume that only one production is possible in
the namespace. `tProdState` is still kept only for display on screen (the
localized text is useful information for the user, it just cannot be used in
the health decision). Validated by testing the same request with
`Accept-Language: pt-BR` via curl before and after the fix.

## 5. Real test (09/09/2026) — evidence, not simulation

With the Monitor up, Experiment 1
(`docs/experiments/01_falha_recuperacao_producao.md`) was reproduced while
querying the Monitor in the middle of the process:

| Moment | `GET /api/guardian/status` |
|---|---|
| Before the failure | all hosts `healthy` |
| ~20s after breaking the destination and firing an incident | `Guardian.Operation.FileOutputOperation` and `Guardian.Process.IncidentRouterProcess` (both sides of the message with an error) change to `degraded`, `recentErrorCount: 1`. `Guardian.Service.FileIncidentService` (not involved in that error) stays `healthy` |
| Destination fixed + new message sent successfully | hosts return to `healthy` as soon as a new message completes successfully on the same path (unrecovered-error rule, 20/09/2026); while the destination remains broken, they stay `degraded` even after the 15 s window expires |

This confirms the Monitor's "Proposed acceptance" (context, section 2): the
failure changes the indicators in a traceable way, and health is neither hidden
nor shown as instantly recovered without a real basis.

## 6. Explicit limitations of this v1 (not hidden)

- **"Degraded" persists after a failure until a new message succeeds on the
  same path** (rules in sections 3/5) — a conscious decision, not a bug; it
  prevents a recent problem from looking "resolved" too early.
- No end-user session authentication beyond the IRIS basic authentication
  already used in the rest of the project.
- No independent scheduled collector (see section 6.1) — the time series only
  grows when someone loads the page or calls the API.

## 6.1 Persisted time series + stuck-host detection (10/09/2026)

Post-Phase 4 reinforcement: the two limitations of the original section 6 ("no
time series", "stuck-host detection not covered") were closed.

- **`Guardian.Monitor.Schema`** — DDL of `Guardian_Monitor.HealthSample`
  (Component, Health, QueueCount, MessageCount, RecentErrorCount, CollectedAt),
  same pattern as the project's other tables.
- **`Guardian.Monitor.StatusCollector.Collect`** now writes one sample per host
  on every call — that is, every time the Monitor page is loaded (it refreshes
  itself every 10s) or the REST API is called, a real sample is persisted.
  There is no independent scheduled collector (`Task Scheduler`) in this v1 —
  the series grows through real use of the application, not through a simulated
  cron.
- **`Guardian.Monitor.StatusCollector.IsStuck(component)`** — a host is
  "stuck" if the last 3 persisted samples have a positive, non-decreasing queue
  over time (the queue is not draining). Insufficient history (< 3 samples)
  returns false — it does not presume a stall without real data. Tested with 4
  controlled data scenarios: queue growing 3/5/7 (stuck = true), queue draining
  7/3/0 (stuck = false), no history (false), only 2 samples even if growing
  (false, insufficient data).
- **`Guardian.Monitor.StatusCollector.RecentSamples`** — the last N samples of
  a component, in chronological order, used by the page to display the queue
  trend.
- **`Guardian.UI.MonitorPage`** — each card now shows a "stuck" badge when
  applicable and a trend line with the latest queue values.
- **Real bug found and fixed**: the first version ordered the samples by
  `CollectedAt DESC`, but `$ZDATETIME($Horolog,3)` only has 1-second
  granularity — samples inserted in the same 1s window (reproduced by testing
  with rapid consecutive inserts) tied and came out of order, breaking the
  detection. Fixed by ordering by `ID` (the real insertion order) instead of
  `CollectedAt`.
- **Real finding, not hidden**: I tried to reproduce "stuck" live by reusing the
  Phase 1 failure experiment (permission denied on the destination) — it did
  not work as expected. That type of failure (write refused by the OS)
  produces a quick error after the 15s `FailureTimeout`, not a sustained queue
  build-up; `Ens.Queue.GetCount` does not show the message as "stuck" during
  the attempt/retry. In other words, the "stuck" detection covers a **different**
  failure mode from the one already demonstrated (a real queue backlog, e.g. a
  disabled host or a slow destination with no timeout) — validated with
  controlled data (above), not with a live reproduction of that specific
  failure mode, which is left as future work if it makes sense for the video.

## 7. Visual validation (09/09/2026) — confirmed

Screenshot `Imagens/Aplicacao/MonitroPage2.jpg`: after the fix in section 4.2,
`Guardian.Service.FileIncidentService` appears **HEALTHY** (green) and
`Guardian.Process.IncidentRouterProcess`/`Guardian.Operation.FileOutputOperation`
appear **DEGRADED** (amber) — exactly the expected state, still within the
window of the test error from section 5. Approved by the owner.

**Phase 2 state: completed, including the time-series and stuck-host detection
reinforcement (section 6.1, 10/09/2026).**

## 8. Next step

Phase 3 — RAG Assistant. Before implementing: the owner's decision on the AI
provider/model for embeddings and generation (a pending item already recorded
in `00_MASTER_PLAN.md` §5 and in the context, section 4) — IRIS native Vector
Search is already confirmed available (VR-001), what remains is choosing what
generates the vectors and the answer.
