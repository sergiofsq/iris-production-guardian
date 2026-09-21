# Phase 5b — Loading UX overhaul and complete i18n coverage

Post-hardening work (09/17/2026), closed from a list of real observations
by the owner using the application (`Ajustes.txt`, items 1 to 4) — not
hypothetical. The 4 prompts below are reproduced **verbatim** (translated
here from the original Portuguese), in the order in which the owner wrote
them (same pattern as the real Phase 0 prompt).

## Prompt 1 — Loader missing on action buttons

```text
whenever there is a button and some processing or search, the Loader must
appear. For example, on the RAG Groq page the Ask button, when clicked,
does not signal this processing to the user. This also happens on the
Investigator page. Review the whole application
```

### Real result (not the expected one — the observed one)

Real root cause, not cosmetic: the mutation that disabled the button and
revealed the overlay happened in the same event tick in which the browser
already started navigating to the next page — the rendering engine never
got to paint the overlay before the old document was destroyed. Fixed
with a pair of shared functions
(`Guardian.UI.Shared.RenderLoadingScript` / `RenderLoadingOverlay`)
reused by the 3 action pages (RAG Gemini, RAG Groq, Investigator).

## Prompt 2 — Incomplete language coverage

```text
The system has to obey the user's language options, so, if PT is
selected, everything must be in Portuguese. Review the whole application
in the 2 languages.
```

### Real result

Hardcoded `<title>`/`<h1>` texts (outside `I18n.T()`) survived earlier
reviews on three pages — Monitor, Investigator and RAG (Gemini). Wired to
the translation dictionary; new keys `monitor.h1`/`investigator.h1` added
to `Guardian.UI.I18n`.

## Prompt 3 — Visual redesign of the busy indicator

```text
Let's change the layout of the busy signal. In the Imagens/Config folder
there is a file named LoaderRosa.jpg. You need to create one, in the color
tones of our application, to replace the current loader we have. It will
appear in the middle of the screen, overlaying the application, which will
be in a dark tone to show inactivity. This behavior is very much like a
modal opening. This loader icon must be animated, spinning. Remove the
white background to give more realism.
```

### Real result

Full-screen modal overlay, semi-transparent dark background, with an
animated radial spinner in **pure CSS** (no image asset at all — less
weight, scales perfectly at any resolution) in the application's teal
palette, inspired by the reference style of `Imagens/Config/LoaderRosa.jpg`
but without the white background.

## Prompt 4 — Logo next to the loader

```text
The Loader turned out great, but I would like the PRODUCTION GUARDIAN logo
to appear next to the loader.. in an elegant way.
```

### Real result

Logo badge, aware of the light/dark theme (reusing the same pattern
already used in the sidebar), positioned next to the spinner inside the
overlay.

## Two real bugs found while testing live (same session, after the 4 prompts above)

They were not part of any prompt — they were found by the owner testing
the result on screen, and fixed on the spot:

- **The loader appeared and disappeared too fast.** Root cause confirmed
  deterministically (deliberately holding a server response open for 2-4 s
  and watching the overlay disappear almost immediately anyway):
  `form.submit()` destroys the old document's JS context **~100-200 ms
  after being called**, not when the server response arrives. Fixed by
  replacing the real navigation with `fetch()` +
  `document.open()/write()/close()`, swapping the HTML in the same
  document instead of navigating — the overlay is not destroyed until the
  response is really ready.
- **The logo appeared huge/cropped.** Root cause: **browser CSS cache**,
  not a code bug — `iris-guardian-theme.css?v=2` had never been
  incremented despite the CSS having been rewritten several times in this
  same session, so the browser kept serving an old copy without the sizing
  rules of the new logo badge (images rendering at native size,
  1983x793px). Fixed by incrementing to `?v=3` on the 4 pages.
  **Lesson applied:** always increment the `?v=` of
  `iris-guardian-theme.css` in the same edit that changes its content.

## Additional adjustment, same session (not requested in a prompt, done for consistency)

The host list in the Production Monitor's sidebar was reordered from
alphabetical to the logical order of the flow — **Service → Process →
Operation** (`Guardian.Monitor.StatusCollector`) — to match the
architecture diagram shown in the recording script and in the manual.

Full dated evidence: commit `c12339f` (09/17/2026) and `Ajustes.txt`
(items 1 to 4, marked `FEITO`).
