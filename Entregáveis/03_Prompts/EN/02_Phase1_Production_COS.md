# Phase 1 — Production COS (Service → Process → Operation)

## Prompt

```text
With the GUARDIAN namespace ready and interoperability enabled, implement
a real Production in pure ObjectScript (no PyProd/BPL) that proves the
path of a message through the three host types:

1. Guardian.Messages.IncidentEvent — message (Ens.Request) representing a
   synthetic incident: component, severity, description.
2. Guardian.Service.FileIncidentService — Business Service using
   EnsLib.File.InboundAdapter, reading .txt files from an input directory
   (one incident per line, fields separated by '|'), archiving the
   original after processing.
3. Guardian.Process.IncidentRouterProcess — Business Process in COS code
   (not BPL), with no business logic yet beyond passing the message on to
   the output Operation, filling in ProcessedBy/ProcessedAt.
4. Guardian.Operation.FileOutputOperation — Business Operation using
   EnsLib.File.OutboundAdapter, writes the processed incident as an
   output file.
5. Guardian.Production.GuardianProduction — connects the three hosts above
   with the correct FilePath/ArchivePath.

After confirming the Production is running and a real message going
through the three hosts (a real SQL query on Ens.MessageHeader, not
inference), implement and reproduce a CONTROLLED FAILURE scenario: break
the write permission of the output directory via chmod (not via
code/mock), trigger a new incident, confirm the real error (#5005) and the
FailureTimeout expiring, fix the permission, confirm that NEW traffic
recovers by itself, and manually resend the message that failed via
Ens.MessageHeader.ResendMessage. Document each command and real result in
docs/experiments/, so that it can be reproduced again during the video
recording.

No simulating the failure "in the interface" — the process must actually
try to write and the operating system must actually refuse.
```

## Real result (not the expected one — the observed one)

- **Real compilation error fixed**: `Ens.BusinessProcess.OnRequest`
  requires `pResponse` to be typed as a subclass of
  `%Library.Persistent` — the first attempt used `%RegisteredObject` and
  compilation failed with `ERROR #5478`. Fixed, recompilation confirmed
  via `%Dictionary.CompiledClass.%ExistsId` (not just by the absence of
  an error on screen).
- Real controlled failure: `chmod 555` on the output directory, real OS
  error captured (`ERROR #5005: Cannot open file ...`), the default 15 s
  `FailureTimeout` of `Ens.BusinessOperation` actually observed expiring.
  Automatic recovery confirmed only for new traffic — the message that
  had already exceeded the timeout stays marked as definitively failed
  (documented framework behavior, not a limitation of the code) and needs
  an explicit `ResendMessage`.
- The script became outdated after the Business Rules bonus (see
  `06_Bonus_Business_Rules_and_Hybrid_Search.md`) changed the destination
  of `CRITICAL` messages to a second Operation — fixed in the clean
  installation check of Phase 5.

Full dated evidence, including the reproducible script:
`docs/planejamento/02_FASE_1_PYPROD_INTEROPERABILITY.md`,
`docs/experiments/01_falha_recuperacao_producao.md`.
