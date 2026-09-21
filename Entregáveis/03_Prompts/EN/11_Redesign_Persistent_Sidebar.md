# UI redesign — persistent sidebar with Production health always visible

Applies after the Monitor (Phase 2), the Investigator (Phase 4) and the
first RAG Assistant (Phase 3) already existed as complete, independent
pages. Without this step, an agent would reproduce three pages that fully
replace each other when navigating — not today's real UI, where the
Production's health stays visible all the time.

## Prompt

```text
The Monitor, Investigator and RAG Assistant pages each currently have their
own header/navigation at the top, and navigating from one to another
replaces the whole page — the Production's health state is lost from view
when leaving the Monitor. Redesign it as a PERSISTENT left sidebar, shared
by the three pages: logo, navigation menu, and a compact live summary of
each Production host (name + health indicator), using the SAME data source
already used by the Monitor's detailed view — do not duplicate the
collection logic.

No heavy client-side JavaScript, no iframe — keep the same server-rendered
page philosophy as the rest of the application. Test live that the three
pages render the sidebar correctly, with the active item highlighted and
the real status of the hosts, and that the Investigator's complete flow
(select component, investigate, read result) keeps working inside the new
layout.
```

## Real result (not the expected one — the observed one)

- New shared component, `Guardian.UI.Shared.RenderSidebar`, reused by the
  three pages — it reuses `Guardian.Monitor.StatusCollector` (the same
  data source as the Monitor's detailed view) instead of duplicating the
  health collection logic.
- Confirmed live: the three pages render the sidebar with the correct
  `aria-current` on the active item and the real status of each host; the
  Investigator's complete flow (select component → Investigate → read the
  result) keeps working inside the new layout.

### Deviation tried and discarded in the same session (documented for transparency, do not repeat)

Before settling on the format above, an attempt was made to open
Investigator/RAG as a **draggable floating modal** over the Monitor
(iframe + JS, `?embed=1`, `iris-guardian-modal.js`). Reverted (`c737244`)
because of UX problems without a simple solution: dragging off-screen with
no way back; Esc did not close it because focus stayed inside the iframe;
clicking on the content of a background modal did not bring it to the
front. The sidebar's compact summary already solves the original goal
("do not lose sight of the Monitor") without any of these problems — it is
not worth reintroducing modal/iframe/drag for this UI.

Kept from the experiment (unrelated to the modal itself, worth keeping):
`Guardian.UI.RAGPage` now shows the Investigator's latest investigation as
context above the RAG form, with a suggested question already filled in.

Full dated evidence: commits `3a850cc` and `c737244` (09/11/2026).
