# Phase 5 — Hardening, clean installation, formal tests, secrets audit

Final phase before delivery — it adds no new functionality, it closes what
is missing so that the delivery is defensible. Four independent prompts.

## Prompt 1 — Installation from a clean checkout

```text
Bring up a NEW Docker container and volume, separate from any environment
already configured, and follow only what is written in the README from
scratch — with no shortcut of configuration already done by hand
somewhere else. Where the README says to use a graphical interface that
cannot be automated (e.g. a Management Portal wizard), look for and
document the equivalent COS command, really testing that it produces the
same result.

Every step that only worked because the reference environment already had
something configured manually becomes a README gap — fix the README, don't
just note the gap. Test the application end to end in the new environment
before considering it done (not just "compiled without error"). Destroy
the test environment at the end; leave nothing behind.
```

### Real result

6 real gaps found and fixed in the README (not hypotheses — each one
really broke when following the original text to the letter): outdated
project status table; "interoperability enabled" with no documented
scriptable equivalent (finding: the `Interop` property of
`Config.Namespaces`); runtime directories of the file adapter never
created by anything; incomplete static-assets step (2 of 4 files were
missing, and one of them — the loading spinner — **had never been
committed to the repository**, it only existed inside the production
container); zero mention of SSL/AI credentials; the 4 `*.Schema.Setup()`
calls (which create the SQL tables on first execution, not at compile
time) not documented anywhere. The entire app (Monitor, Investigator, RAG
with real ingestion and citation) confirmed working end to end in the new
container before tearing it down.

## Prompt 2 — Formal tests of the 4 required paths

```text
Formalize, with reproducible evidence (not "I saw it happen once"), the 4
required paths: complete healthy path; real destination failure (really
break the permission, do not simulate); component/RAG with insufficient
data (must say "I don't know"/"0 events", never invent); AI model
unavailable (do not wait for a usage-limit error to happen by chance —
force a deterministic and reversible one, without leaving the real
credential broken at the end).

Before running any test, confirm that the Production is actually running
— do not assume it from the state of the last session.
```

### Real result

The Production was **stopped** at the start (not just "having a problem")
— it required `##class(Ens.Director).RecoverProduction()` **with no
arguments** (passing the Production name gives a `<PARAMETER>` error)
before `StartProduction` worked. The destination failure test revealed
that the documented script was **outdated because of the Business Rules
bonus**: breaking the old directory with a `CRITICAL` message caused no
failure at all, because that severity had been going to a different
destination since the routing bonus — the script was fixed, not just the
test. Model unavailability was formalized by replacing the real credential
with an invalid value in a single session, capturing the real HTTP error
from the API, and restoring the original credential before leaving —
confirmed with a real call afterwards that it was working again.

## Prompt 3 — Secrets audit

```text
Check that no real credential (passwords, API keys) is in versioned code,
PUBLISHED TO GIT, a published log, or outreach material (manual, screenshots)
— don't just check the current state of the repository: search the WHOLE
git history, because a secret that was already removed is still exposed in
old commits if the repository is public. Also check any image/screenshot
used in publishable documentation for unintended personal information (not
just technical secrets).
```

### Real result

No real secret found in any commit ever made (`git log --all
-S"<pattern>"` for the known key prefixes). A finding that is NOT a secret
but is a privacy matter: 7 screenshots used in the user manual showed the
owner's entire browser bookmarks bar (the beginning of a personal e-mail,
names of personal folders) — fixed by cropping the source images AND the
images already embedded inside the `.docx` (mathematically recalculating
Word's crop rectangle instead of reopening the program), confirmed pixel
by pixel that nothing changed in what was already shown when reading the
document normally.

## Prompt 4 — Reverse-engineered documentation (this file and the Prompts/ folder)

```text
Reread the entire README against the REAL behavior of the system today —
not against what you remember having implemented. Every sentence must
correspond to something you just observed running, not to an assumption of
how it should be. Then reconstruct by reverse engineering the sequence of
prompts that, given to an agent from scratch, produce this application
exactly as it is — grounded in the real code and in the friction/fixes
already documented in each phase, not an idealized version without the
errors that actually happened.
```

### Real result

It is this file and the 8 previous ones in `entregaveis/Prompts/`, plus
the fix of the README's status table and of the "Repository layout"
section (`entregaveis/` was missing, the bonuses were not listed as ready
features — the README said "not started" for 4 modules that had already
been ready and tested for days).

Full dated evidence: `docs/planejamento/06_FASE_5_HARDENING_TESTS_DEMO.md`.
