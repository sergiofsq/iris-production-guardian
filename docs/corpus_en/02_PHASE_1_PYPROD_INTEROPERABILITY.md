# Phase 1 — COS Production / Interoperability

> File name preserved from the history (`02_PHASE_1_PYPROD_INTEROPERABILITY.md`),
> but the content prioritizes a Production in COS, per the mandatory premise
> (context, section 1.1). PyProd was neither implemented nor claimed — see
> `01_PHASE_0_SETUP_ARCHITECTURE.md` §6, item 3.

## 1. Goal of this phase

Prove the path of a real message through the three host types of an IRIS
Production (Service → Process → Operation), using a natively supported
adapter, with no dependency external to IRIS. This is the infrastructure
prerequisite for the Production Monitor (Phase 2).

## 2. What was implemented

Source code in `src/Guardian/` (edited via VS Code + the InterSystems
ObjectScript extension, connected to the `GUARDIAN` namespace of the
`iris-guardian` container, automatic compilation on save):

| Class | Role | Adapter |
|---|---|---|
| `Guardian.Messages.IncidentEvent` | Message (`Ens.Request`) with the data of a synthetic incident | — |
| `Guardian.Service.FileIncidentService` | Business Service — reads `.txt` files (one incident per line, fields separated by `\|`) | `EnsLib.File.InboundAdapter` |
| `Guardian.Process.IncidentRouterProcess` | Business Process (code, not BPL) — fills in `ProcessedBy`/`ProcessedAt` and routes to the Operation | — |
| `Guardian.Operation.FileOutputOperation` | Business Operation — writes the processed incident as an output file | `EnsLib.File.OutboundAdapter` |
| `Guardian.Production.GuardianProduction` | Production that connects the three hosts above | — |

Data directories (inside the durable volume, they survive `docker rm`):
`/durable/guardian/in` (input), `/durable/guardian/archive` (processed files),
`/durable/guardian/out` (output — the "controlled demonstration destination"
mentioned in the MVP).

Business Rules **were not used here** — routing is simple code in the Process.
The Business Rules engine (`Ens.Rule.Definition`) is a separate bonus (+2),
implemented later — see §6.

## 3. Test executed (09/09/2026) — real evidence, not simulated

1. Production started: `##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")` → `%Status` OK, state confirmed "running" via `Ens.Director.GetProductionStatus`.
2. File dropped in `/durable/guardian/in/demo1.txt`:
   ```
   INC-001|IRIS.Service.OrderIngest|HIGH|Message queue above the configured limit
   ```
3. After the adapter's polling interval (5s), the file:
   - disappeared from `in/`;
   - appeared archived in `archive/demo1.txt_2026-09-09_17.28.15.298`;
   - produced `out/incident_INC-001.txt` with the content:
     ```
     INC-001|IRIS.Service.OrderIngest|HIGH|Message queue above the configured limit|2026-09-09 17:28:15|Guardian.Process.IncidentRouterProcess|2026-09-09 17:28:15
     ```
     The last two fields (`ProcessedBy`, `ProcessedAt`) only exist because the
     Process really ran — it is not an empty pass-through.
4. Trace in `Ens.MessageHeader` (real SQL query, not inferred):

   | ID | Source → Target | Status |
   |---|---|---|
   | 2 | `Guardian.Service.FileIncidentService` → `Guardian.Process.IncidentRouterProcess` | 9 (completed) |
   | 3 | `Guardian.Process.IncidentRouterProcess` → `Guardian.Operation.FileOutputOperation` | 9 (completed) |
   | 4 | `Guardian.Operation.FileOutputOperation` → `Guardian.Process.IncidentRouterProcess` (synchronous response) | 9 (completed) |

   (ID 1, `Ens.ScheduleService` → `Ens.ScheduleHandler`, is internal Production
   traffic and is not part of the functional flow.)

**Conclusion: a real message crossed Service → Process → Operation, with a
supported adapter (`EnsLib.File`), with evidence in a file and in
`Ens.MessageHeader`.** Covers the "Service, Process and Operation" (+1) and
"Adapter on a host" (+1) bonuses of the matrix — see the record in
`07_EVIDENCE_SCORECARD.md`.

## 4. Real error found and fixed during development

When compiling `Guardian.Process.IncidentRouterProcess`, IRIS refused with:

```
ERROR #5478: Keyword signature error ... Method:OnRequest, keyword 'method
argument/s signature' must be '%Library.Persistent,%Library.Persistent' or
its subclass
```

Cause: the `OnRequest` method of `Ens.BusinessProcess` requires the output
parameter (`pResponse`) to be typed as a subclass of `%Library.Persistent`; the
first version used `%RegisteredObject`, which is not a subclass of
`%Persistent`. Fixed by switching to `%Persistent`. Recompiled successfully —
confirmed via `%Dictionary.CompiledClass.%ExistsId`, not only by the absence
of an error message.

## 5. Controlled failure and recovery scenario (09/09/2026) — real evidence

The complete, reproducible script is in
`docs/experiments/01_falha_recuperacao_producao.md` (run from scratch twice in
this session, with an identical result — it is not a hypothetical example).

Summary of what was observed:

1. Destination broken (`chmod 555` on `/durable/guardian/out`, removing write
   access from `irisowner`).
2. Incident `INC-003` fired. After ~15s (the framework's default
   `FailureTimeout`, confirmed in `Ens.BusinessOperation||FailureTimeout` =
   `15`, `RetryInterval` = `5`), the Operation records in
   `Ens.MessageHeader.ErrorStatus`:
   ```
   <Ens>ErrFailureTimeout ... ERROR #5005: Cannot open file
   '/durable/guardian/out/incident_INC-003.txt'
   ```
   No output file is generated — the failure is real (an operating system
   error), not faked in the interface.
3. Destination fixed (`chmod 755`).
4. A **new** incident (`INC-004`) flows automatically and successfully —
   this confirms automatic recovery for new traffic, without restarting the
   Production.
5. The incident that failed (`INC-003`) is **not** redelivered on its own — the
   `FailureTimeout` had already expired before the fix, so that specific attempt
   was left marked as a definitive failure (documented behavior of the
   `Ens.BusinessOperation` framework, not a limitation of the project's code).
   Resent manually via `##class(Ens.MessageHeader).ResendMessage(<ID>)` —
   success confirmed (output file generated).

This directly covers the "Proposed acceptance" of the Production Monitor
(context, section 2): a failure changes indicators traceable to the original
event, and the recovery (automatic for new traffic, manual for the affected
message) is visible — nothing was hidden or faked as success.

## 6. Business Rules (+2 bonus) — real rule-based routing, 10/09/2026

Closes the pending item recorded in section 4: routing stopped being fixed code
in the Process and became decided by a real `Ens.Rule.Definition` class,
editable in the Management Portal Rule Editor (Interoperability > Business
Rules) without recompiling anything.

**Implemented:**

- `Guardian.Rule.IncidentRoutingRule` (`Extends Ens.Rule.Definition`):
  `XData RuleDefinition` with `context="Guardian.Messages.IncidentEvent"`, a
  `RouteBySeverity` rule that returns the destination config name —
  `Guardian.Operation.PriorityOutputOperation` when
  `(Severity="HIGH")||(Severity="CRITICAL")`, otherwise
  `Guardian.Operation.FileOutputOperation` (`<otherwise>`).
- `Guardian.Process.IncidentRouterProcess.OnRequest` calls
  `##class(Ens.Rule.Definition).EvaluateRules("Guardian.Rule.IncidentRoutingRule", "", pRequest, "", .tTarget, .tReason)`
  and sends the message to `tTarget` (instead of the fixed `TargetConfigName`,
  which now only serves as the initial fallback value).
- A second Operation added to the Production
  (`Guardian.Operation.PriorityOutputOperation`, same class
  `Guardian.Operation.FileOutputOperation`, pointing to
  `/durable/guardian/out_priority`) — without it, "real routing" would not have
  two possible destinations to prove.

**Test executed (10/09/2026) — real evidence, not simulated:**

1. `INC-101` (`HIGH`) and `INC-102` (`LOW`) dropped in `in/`. Result:
   `INC-101` → `out_priority/incident_INC-101.txt`; `INC-102` →
   `out/incident_INC-102.txt`. Confirmed by `Ens.MessageHeader`: the `Process`
   dynamically routed to different operations in the same run, without any code
   change between the two messages.
2. **Rule condition changed** (added `||(Severity="MEDIUM")`) and recompiled —
   no change in `IncidentRouterProcess` or in the Production. `INC-103`
   (`MEDIUM`), which would previously land in `out/`, started landing in
   `out_priority/incident_INC-103.txt`. This is the proof asked for by the
   contest criterion ("change a condition in a test and observe the result"):
   the behavior changed because the rule changed, not because the Process code
   changed.
3. Compilation done via `iris session IRIS -U GUARDIAN` +
   `$system.OBJ.Load(..., "ck")` inside the container (not through the VS Code
   extension in this session) — same observable result in the Portal's Rule
   Editor.

**State: confirmed.** See the record in `07_EVIDENCE_SCORECARD.md`.

## 7. Pending items of this phase (not done yet)

- No message has yet been generated with a **real "Production" load observable
  in the Monitor** — that is Phase 2 (already addressed separately by that
  phase).

## 8. Next step

Start Phase 2: collect the real state of hosts/queues via `Ens.*` classes (what
we already explored manually here — `Ens.MessageHeader`, `Ens_Config.Item`) to
feed the Production Monitor.
