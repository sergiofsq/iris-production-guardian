# Phase 2 — Production Monitor

## Prompt

```text
With the Phase 1 Production running, build the Production Monitor: a web
page that shows the real state of the GuardianProduction hosts (Services,
Processes, Operations) — healthy, degraded, unavailable, unknown — with no
invented numbers.

1. Guardian.Monitor.StatusCollector — collects, per host: whether it is
   enabled and whether the Production/host is actually running
   (##class(Ens.Director) — not a comparison of status text, see the real
   friction below), queue count, message count, recent error count
   (configurable time window). Data source: real Ens.* classes, never a
   fixed/simulated value.
2. Guardian.API.MonitorAPI — endpoint that returns this state as JSON.
3. Guardian.UI.MonitorPage — %CSP.Page page (simple HTML, no JS
   framework) that renders the card of each host, colors by state, and
   persists a time-series sample on every load (to provide a minimal
   history without needing a dedicated scheduler in this v1).
4. Add "stuck host" detection: positive queue that has not drained in the
   last N persisted samples — test with at least one real controlled
   scenario (not a fabricated number) before declaring that it works.

State rules (document explicitly, do not leave them implicit in the
code): unavailable = host disabled or Production stopped; healthy = no
pending queue and no recent error; degraded = pending queue or error in
the last N seconds; unknown = no message recorded yet for that host. Test
the page both via curl and in a real browser before declaring it complete
— one can hide a bug that the other reveals.
```

## Real result (not the expected one — the observed one)

- **Real compilation error**: a `Parameter ERROR_WINDOW_SECONDS = 900`
  referenced as `..#ERROR_WINDOW_SECONDS` broke the parser with
  `ERROR #5559` (a generic message, not pointing to the right line) — root
  cause isolated by bisection: `_` is the COS concatenation operator, and
  `..#NAME_REST` is read as `(..#NAME)_(REST)`, not as a single
  identifier. Fixed by renaming the parameter to PascalCase without an
  underscore (`ErrorWindowSeconds`). There was no explicit documentation
  of this before testing — knowledge verified empirically.
- **Real bug, found only by the owner testing in the browser** (not by the
  curl tests): all hosts appeared as `unavailable` even with the
  Production running normally — only in pt-BR. Cause: the rule compared
  `$List(tProdEntry,1) = "Running"` (text), but that text is **localized
  by the browser's language** (`Accept-Language: pt-BR` makes IRIS return
  "Em execução"). Fixed by switching to
  `##class(Ens.Director).IsProductionRunning()`, which returns a real
  `%Boolean`, not text. Proof that testing only via curl (without a
  language header) hid the bug.
- Time series: real bug in the ordering (it used ID instead of
  `CollectedAt` — the same thing in most cases, but not always) fixed
  after being observed live.

Full dated evidence:
`docs/planejamento/03_FASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md`.
