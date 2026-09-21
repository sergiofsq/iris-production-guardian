# Phase 0 — Setup and architecture

Real prompt, reproduced verbatim from
`docs/planejamento/IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` §12
— it was the prompt that actually started this project, not a
reconstruction.

> Translator's note: the prompt below is an English translation of the
> original Portuguese prompt.

## Prompt

```text
You are going to implement the IRIS Production Guardian. First read
IRIS-Production-Guardian-CONVERSATION-CONTEXT.md and the applicable local
instructions. Treat the architecture as a proposal and the history as
context, never as proof of APIs, tests or existing files.

Start with Phase 0. Before implementing:
1. Inspect the directory, the Git state and the specification files
   00_MASTER_PLAN.md to 07_SCORECARD_EVIDENCIAS.md, if they exist. Do not
   overwrite changes. Record absences and divergences.
2. Identify the system, CPU architecture, runtimes and tools actually
   available, without displaying secrets. Check IRIS: installation/image,
   version, edition, required license, namespace and available
   Production. If something cannot be observed, record that limitation.
3. Apply the mandatory premise: COS/ObjectScript for everything possible;
   all databases exclusively InterSystems IRIS; Python only for proven
   COS limitations, with justification and minimal scope. First inspect
   the COS resources of the real version. Do not install PyProd just for
   the contest: record the conflict and obtain an explicit decision before
   any exception to the COS priority. If Python is necessary, check the
   supported versions and integration, without selecting by assumption.
4. Consult the official documentation relevant to the identified version.
   Confirm the mechanisms of interoperability, collection, persistence and
   search before writing calls. For bonuses, run minimal feasibility
   proofs.
5. Revalidate the contest rules and build the scorecard separating
   published points, proposals and evidence. Do not use 37 as a confirmed
   official ceiling.
6. Record VERIFY_REQUIRED for each doubt, with impact, required
   source/test and next step. Investigate what is within your reach; ask
   the owner only what requires their access or decision.
7. Produce a concise diagnosis, the proposed executable architecture and
   an incremental Phase 0 plan with exit criteria. Record the versions and
   sources checked. Do not say a test passed without having run it.

After validating the prerequisites, advance through the authorized steps
in small increments, preserving the three MVP modules and the 09/21/2026
deadline. Block only the part that depends on missing information.
Document prompts, fixes, tests and commits from the first increment. Use
identified demonstration data; never invent APIs, metrics, citations,
results or ready-made features. End each step with evidence, limitations
and a concrete next step.
```

## Real result (not the expected one — the observed one)

- Image `intersystems/iris-community:latest-cd` chosen; the `-arm64`
  variant was discarded because of an expired Community license (a real
  finding, not a hypothetical one).
- Ports remapped (`51972`→1972, `53773`→52773) because the owner's
  machine already had other IRIS instances on the default ports.
- The `demo`/`_SYSTEM` user expected by the `IRIS_USERNAME`/`IRIS_PASSWORD`
  environment variables **does not actually exist** in the image — a
  dedicated `guardian`/`guardian` user (role `%All`) was created manually.
- Vector Search and Foreign Table confirmed available without an extra
  license; IntegratedML confirmed **unavailable** (proprietary
  `iris_automl` package missing from the image) — recorded as a definitive
  blocker, not worked around.
- Namespace `GUARDIAN` / database `GUARDIANDB` created with
  interoperability enabled — the exact mechanism (the `Interop` property
  of `Config.Namespaces`) was only documented later, in the clean
  installation check of Phase 5 (see
  `09_Phase5_Hardening_Install_Tests.md`).

Full dated evidence:
`docs/planejamento/01_FASE_0_SETUP_ARQUITETURA.md`.
