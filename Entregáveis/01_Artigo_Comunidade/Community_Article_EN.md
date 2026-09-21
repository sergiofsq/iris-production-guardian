<!--
DRAFT — to be published on the InterSystems Developer Community (PT community).
English translation of Artigo_Comunidade_PT.md.
Fill in before publishing: [IRIS Production Guardian on Open Exchange](https://openexchange.intersystems.com/package/IRIS-Production-Guardian), (video already filled in), [@Sergio.Fernandes](https://pt.community.intersystems.com/user/sergio-fernandes),
real screenshots (today there is only a textual reference to the screens).
Mandatory contest tags: #Concurso #ConcursoProgramacaoIA #AIProgramContest
-->

# IRIS Production Guardian: building an AI observability copilot for IRIS — and documenting every fix along the way

*Submission for the InterSystems PT Developer Community Programming Contest 2026.*
*Author (solo development, no team): Sérgio Fernandes de Sousa Quinta — [@Sergio.Fernandes](https://pt.community.intersystems.com/user/sergio-fernandes)*
*Application: [IRIS Production Guardian on Open Exchange](https://openexchange.intersystems.com/package/IRIS-Production-Guardian) · Repository: [github.com/sergiofsq/iris-production-guardian](https://github.com/sergiofsq/iris-production-guardian) · Video: [YouTube](https://youtu.be/dDCw5pywdH8)*

## The problem

Anyone who administers an IRIS Production knows the question that always
arrives too late: "why did this component stop responding, and since
when?" The answer usually lives in three different places — the Management
Portal, the logs, and the head of whoever has seen that error before. The
**IRIS Production Guardian** tries to bring those three places together in
a single application, built entirely on InterSystems IRIS: a monitor that
shows the real state of each component, an incident investigator that
gathers real evidence and asks an AI model for an analysis in which
hypothesis is kept separate from observed fact, and an assistant that
answers questions about the project's documentation while citing the
source — and saying "I don't know" when it doesn't, instead of making
things up.

Three constraints guided every technical decision, from the first commit
to the last: ObjectScript first (no external application framework), IRIS
as the only database (native Vector Search and Foreign Tables cover what
would normally call for a separate vector database), and Python only where
COS demonstrably could not solve the problem — in practice, the final
project did not need a single line of Python.

## Architecture, in one picture

```text
Web UI: Monitor | Investigator | RAG Assistant (Gemini) | RAG Assistant (Groq)
                       |
Application layer: queries, investigation, hybrid retrieval
                       |
InterSystems IRIS: persistence and interoperability
      |                |                    |
Production COS      Events/metrics      Documents/vector indexes
      |
Service -> Process -> Operation (routing by Business Rule)
```

Two independent Productions run in the same namespace: the main one, which
processes synthetic incidents through a classic Service → Process →
Operation path, and a second one, dedicated to the public API access
bonus, which does real polling of an external service that requires no
authentication key.

## What is done (and tested, not just implemented)

The three MVP modules — **Production Monitor**, **AI Incident
Investigator** and **RAG Assistant** — and the four bonus items —
severity-based routing with **Business Rules**, **hybrid search** (vector
+ lexical) in the RAG, **access to a real public API** (a second
Production consuming `disease.sh`) and **multi-model** (a second AI
provider, Groq, genuinely wired into the RAG generation step) — are
implemented and tested live. The complete technical documentation, with
dated evidence for each item, is in
[`docs/planejamento/07_SCORECARD_EVIDENCIAS.md`](https://github.com/sergiofsq/iris-production-guardian/blob/main/docs/planejamento/07_SCORECARD_EVIDENCIAS.md)
and in the [complete project documentation](https://github.com/sergiofsq/iris-production-guardian/tree/main/Entreg%C3%A1veis/02_Documentacao)
(PT/EN, in PDF).

One decision worth highlighting: when the "multi-model" bonus came up, the
obvious temptation would have been to clone the RAG Assistant page and
change only the menu text. Instead, the second provider (Groq) was
actually wired into the **generation** step — retrieval/embeddings remain
with the main provider (Gemini), because we confirmed, by testing against
the real API before deciding the architecture, that Groq does not even
offer an embeddings endpoint on the free tier. Re-ingesting the whole
corpus into a new vector space just to "look" multi-model would have had
no real value — what matters for the criterion is that the answer comes
from a genuinely different model, and that was tested end to end through
the real page, not only through the isolated client.

## AI development methodology

The project was built with Claude Code, following a set of strict rules
recorded since Phase 0: never declare something tested without observing a
real execution; never invent classes, methods or results; explicitly
record every technical pending item until there is evidence; and always
distinguish planned, implemented, tested and demonstrated — the difference
between these four words shows up in practically every commit of this
repository.

The real sequence of prompts that reproduces this application — the prompt
that actually started the project in Phase 0, reproduced verbatim, and the
others reconstructed by reverse engineering from the code and the commits
where the original text was not preserved — is published in
[`Entregáveis/03_Prompts/`](https://github.com/sergiofsq/iris-production-guardian/tree/main/Entreg%C3%A1veis/03_Prompts),
one file per phase/bonus. Each one pairs the prompt with the real errors
found at that stage — not an idealized version of the process.

### Real examples of errors and fixes

Not every AI agent "hallucination" is about inventing facts — most of the
ones found here were about **outdated knowledge** or **unverified
assumptions**, corrected against real evidence, not against the model's
memory:

**1. Outdated AI model name, twice, with two different providers.** When
integrating Gemini, the first attempt used `gemini-2.5-flash` — the API
answered with a real 404: *"This model ... is no longer available to new
users ... use models/gemini-3.6-flash"*. Weeks later, when integrating
Groq, the same pattern repeated with a Llama model that existed in the
agent's knowledge but had already left the provider's catalog — fixed by
querying the API's own model-listing endpoint with the real key, not by
guessing a second name.

**2. An IRIS API that does not exist.** `%SQL.Statement` has no
`%GetLastIdentity()` — the code tried to use that method by analogy with
other data-access frameworks, and COS refused it. `LAST_IDENTITY()` via
SQL also does not work when called in a statement separate from the INSERT
(tested and confirmed empty before discarding that alternative too). The
real solution was `%ROWID` from the INSERT's own result set.

**3. A false alarm investigated and ruled out, not blindly "fixed".**
Debugging the Gemini API through the Docker terminal showed accented
characters corrupted as `�`. The naive reaction would be to "fix the
encoding" — instead, a hexdump of the real HTTP bytes (via curl) confirmed
perfect UTF-8 end to end. The bug was only in the display of the debugging
terminal, not in the application. It is recorded as a rule: never assume
an encoding bug from terminal output, always check the real bytes first.

**4. A bug found by the project owner, not by the automated tests — and
why that matters.** Testing via `curl` (without a language header), the
Monitor looked perfect. Only when the owner opened the page in a real
browser (`Accept-Language: pt-BR`) did all hosts appear as `unavailable`,
even with the Production running. Cause: the code compared the *text* of
the status (`"Running"`) returned by `Ens.Director.GetProductionSummary` —
and that text is localized by IRIS according to the browser's language,
becoming `"Em execução"` in Portuguese. The fix replaced the text
comparison with `##class(Ens.Director).IsProductionRunning()`, which
returns a real boolean. The lesson recorded: an automated test without the
right header can hide exactly the bug that a human using the real
application finds in seconds.

**5. An assumption about the graphical interface with no documented
equivalent — resolved by trial and error against the real system, not by
external documentation.** While checking whether an installation from a
clean checkout worked (Phase 5), I found that "enable interoperability" —
a checkbox in the Management Portal wizard — has no documented equivalent
command anywhere accessible. Instead of leaving this as a gap, I queried
IRIS's own class dictionary (`%Dictionary.PropertyDefinition` for the
`Config.Namespaces` class) and found the right property (`Interop`) by
real trial and error against the system, not by assumption. This became a
concrete fix in the README, not just a footnote.

**6. A test script that became outdated because of the project's own
progress — found live, not hypothetical.** The Production failure/recovery
script, written in Phase 1, broke the destination directory of a
`CRITICAL` message to simulate a real failure. After the Business Rules
bonus (Phase 1, later item) started routing high severities to a different
physical destination, that same script stopped causing any failure —
confirmed live, before fixing it, that breaking the old directory simply
had no effect. The fix was not only in the test code: it was in the script
file itself, so that the final video recording does not trip over the same
problem.

More examples, with the exact prompt and the real result of each phase,
are in
[`Entregáveis/03_Prompts/`](https://github.com/sergiofsq/iris-production-guardian/tree/main/Entreg%C3%A1veis/03_Prompts).

## Formal tests — the four required paths

Besides the tests of each phase, the project formalized live the four
paths that the internal Definition of Done requires: **complete healthy
path** (a real message going through Service → Process → Operation),
**real destination failure** (write permission actually removed via
`chmod`, real `#5005` error captured, automatic recovery confirmed for new
traffic, manual resend for the message that failed), **lack of data** (the
RAG answers "I don't know" to an irrelevant question instead of making
something up; the Investigator correctly reports "0 events" in a window
with no traffic), and **AI model unavailability** (formalized as a
deterministic case: the real credential was replaced by an invalid value
in a single session, the real HTTP error captured, and the original
credential restored before leaving — without depending on waiting for a
usage limit to be hit by chance).

## Reproduction

The [`README`](https://github.com/sergiofsq/iris-production-guardian#running-it-locally)
documents the complete installation, end to end — genuinely verified on an
installation from a clean checkout (disposable Docker container and
volume, with no already-configured environment shortcut). That exercise
alone found six real documentation gaps, all fixed: from the outdated
status table to a static asset file (the interface's loading spinner) that
had never been versioned in the repository — it existed only inside the
production container. Full details in
[`docs/planejamento/06_FASE_5_HARDENING_TESTS_DEMO.md`](https://github.com/sergiofsq/iris-production-guardian/blob/main/docs/planejamento/06_FASE_5_HARDENING_TESTS_DEMO.md).

## Limitations, honestly

Not everything is closed. IntegratedML is confirmed **unavailable** in
this Community image (the proprietary `iris_automl` package is missing) —
it was not worked around, only documented as a real blocker since Phase 0.
The RAG documentation corpus (12 documents) has 5 external pages ingested
manually, with no reproducible re-ingestion script yet — a real gap,
recorded, not hidden. And two points depend only on the contest
organization: the official cutoff time/time zone for submission, and the
interpretation of the bonus ceiling.

## Closing

This article, like the rest of the project, tried to follow the same
yardstick: nothing declared as tested without having really been tested,
nothing hidden just because it would make a better narrative. The code,
the phase documents with dated evidence, and the complete sequence of
prompts are all in the
[repository](https://github.com/sergiofsq/iris-production-guardian) —
application in English, article in Portuguese, as per the rules.

#Concurso #ConcursoProgramacaoIA #AIProgramContest
