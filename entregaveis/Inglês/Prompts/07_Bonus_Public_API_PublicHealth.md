# Bonus — Access to a real public API (PublicHealth)

## Prompt

```text
Implement the "adequate public API access" bonus: a second, independent
Production that consumes a real public API (no authentication), with an
honest cache/unavailability pattern — never invent data.

1. Guardian.Messages.PublicHealthSnapshot — message with the snapshot
   fields coming from the API + provenance metadata (did it come live? is
   it cache? from when? which error caused the fall back to cache, if
   applicable).
2. Guardian.Adapter.PublicHealthPollAdapter — a CUSTOM Ens.InboundAdapter
   (not the generic InboundAdapter) doing real polling of a public API
   with no key. Attention: the OnTask method of a custom InboundAdapter is
   called by the framework much more often than the configured
   CallInterval — the adapter itself must track the elapsed time and do
   nothing until the interval expires, otherwise it hammers the public API
   continuously.
3. Guardian.Operation.PublicHealthOutputOperation — sole owner of the
   snapshots table. On a successful poll, it writes the "live" row. On
   failure, it falls back to the last known real value, explicitly
   labeled as cache (with the age calculated from the original fetch) and
   the HTTP status that caused the fall back. If there is no cache yet, it
   marks honest unavailability — never invents a number.
4. Guardian.Production.PublicHealthProduction — separate Production (only
   one Production runs per namespace at a time in this environment;
   document that as an operational limitation, do not invent support for
   multiple).

Prove it with a real FORCED FAILURE test: point the adapter to an invalid
endpoint (not a mock), confirm the real HTTP error (e.g. 404), confirm
that the cache fallback triggers with the correct age and status, then
restore the correct endpoint and confirm it goes back to writing live.
```

## Real result (not the expected one — the observed one)

- API chosen: `disease.sh/v3/covid-19/all` — public, no key.
- **Real framework friction**: `OnTask` of a custom `Ens.InboundAdapter`
  is called many more times than the configured `CallInterval` — without
  its own elapsed-time control, the adapter would hammer the public API
  continuously. Solved with its own field (`LastPollTotalSecs`) that on
  every call checks whether the real interval has expired before making
  any request.
- **Real deployment friction**: recompiling the class, or changing a
  Setting and calling `UpdateProduction`, **does not reliably reload** the
  code/property values of a job that is already running — it needs a real
  Stop + Start of the Production, with a few seconds between the two.
- Real forced-failure test: endpoint switched to an invalid path, real
  `HTTP 404` captured, cache fallback triggered with the right age and the
  404 status labeled as the cause — never an invented number. Correct
  endpoint restored afterwards, confirmed going back to writing a "live"
  row.
- **Historical note**: the first attempt at this bonus was a separate
  project (its own namespace/folder, different class name, teaching the
  pattern from scratch) — abandoned after only the initial setup, because
  the same idea made more sense inside the main repository, as it is
  today. Do not reopen that separate path.

Full dated evidence:
`docs/planejamento/07_SCORECARD_EVIDENCIAS.md` ("Public API access —
PublicHealth" section), commit `67b00b9`.
