# Bonus — Business Rules (real routing) and hybrid search in the RAG

Two independent bonuses, each with its own prompt — they were done at
different moments of the real project.

## Prompt 1 — Business Rules (+2)

```text
The routing of the incident to the output Operation is currently
hard-coded in the Process. Replace it with a real, editable business
rule:

Create Guardian.Rule.IncidentRoutingRule (Ens.Rule.Definition, visually
editable in the Management Portal's Rule Editor, without having to
recompile the Process) that decides the destination by the incident's
Severity: HIGH/CRITICAL/MEDIUM goes to a separate priority Operation (a
new physical destination, it cannot be the same directory as the default
Operation — otherwise "real routing" would not be demonstrable); the
others continue on the current Operation. Configure the new Operation in
the Production with its own destination.

Prove it with a real test: send a CRITICAL message and confirm that it
arrives at the new destination, not the old one. This is also the script
that Phase 5 will need to reconfirm whenever something in the routing
changes — the failure/recovery experiment (Phase 1) depends on knowing
which directory to break for each severity.
```

### Real result

`Guardian.Rule.IncidentRoutingRule` with a `RouteBySeverity` rule
returning the name of the destination config item; new Operation
`Guardian.Operation.PriorityOutputOperation` writing to
`/durable/guardian/out_priority` (a separate physical directory — without
it, the routing would not be provable, just a string return with no
observable effect). Tested live by sending a `CRITICAL` message and
confirming the file in the new directory, not the old one.

## Prompt 2 — Hybrid search in the RAG (+3)

```text
The RAG Assistant's retrieval is currently vector-only (cosine). Add
LEXICAL search (IRIS's native full-text, no external dependency) and fuse
the two rankings before building the final TopK — do not replace the
vector one, complement it.

Use a native IRIS full-text index on the chunk text, created in the schema
setup. Fuse the two rankings with Reciprocal Rank Fusion (RRF), a
standard IR algorithm (do not invent an ad hoc weighting scheme). If the
index's native ranking API does not accept the expected syntax in a live
test, do not force it or guess the right syntax — record the limitation
and use a simpler and honest signal (e.g. a fixed bonus per match)
instead of faking a rank position that was not really calculated.

The abstention threshold already calibrated (Phase 3) must not change
basis: it continues to be decided only by pure vector similarity, never by
the combined fusion score — otherwise the earlier calibration becomes
invalid without new evidence. Test with at least 3 real questions,
including an irrelevant one, confirming that the fusion did not break the
abstention.
```

### Real result

`%iFind.Index.Basic` index on `Guardian_RAG.Chunk.ChunkText`, confirmed
working on the Community Edition without an extra license. Fusion via RRF
(`k=60`, the reference value from the literature, with no tuning for this
small corpus). **Real limitation found and not hidden**: iFind's native
ranking API (`%iFind.Rank`) refused the expected syntax (`Field
'IDXCHUNKTEXTFIND' not found`) — instead of guessing, a lexical match now
adds a fixed bonus (equivalent to rank 1) in the fusion, recorded as an
honest simplification, not a fine-grained relevance metric. Tested with 3
real questions: a specific technical one (retrieved and cited correctly,
no abstention), an irrelevant one ("chocolate cake recipe", abstention
maintained — confirms that the fusion did not break the calibration), and
one that exposed a real Gemini timeout on the first attempt (it worked on
the second).

Full dated evidence:
`docs/planejamento/02_FASE_1_PYPROD_INTEROPERABILITY.md` §6 (Business
Rules), `docs/planejamento/04_FASE_3_RAG_ASSISTANT.md` §6 (hybrid
search).
