# OCR / Conversion Sanity Check (agent-agnostic)

Procedure for making a PDF-derived `source-text` page **trustworthy** before it becomes ground truth. This is steps 2–4 of the source-first ingest (see [memory-architecture.md](memory-architecture.md)) for the PDF path: convert → extract figures → *review*. Agent-agnostic; the harness overlay (Claude Code's `pdf-ingest` skill, etc.) drives it.

The reason it exists: the `sources/` layer is the anti-hallucination substrate. A conversion that silently drops a figure, garbles a column, or scrambles reading order poisons every synthesis that grounds on it. So a human/agent looks before it's trusted — and the figures, which often carry the real content, get *seen*, not assumed.

## Input

`pdf2md` output (`scripts/pdf-to-markdown/`): `sources/<slug>.md` (with `figures_reviewed: pending`) and `assets/<slug>/fig-NN.png`.

## Checks

1. **Text fidelity.** Skim for OCR/encoding garble, broken words, repeated/looping runs. Confirm section headings survived (they are the grounding anchors). Watch for **reading-order anomalies** — multi-column journals and "proof" headers often get merged on the first page (title + abstract + keywords + intro fused into one run).
2. **Figure legibility.** *View* the figures and judge whether the content is actually readable — for schema/diagram-heavy sources, the fine edge labels matter, not just the boxes. Note any cropped, blank, or too-low-resolution to understand.
   - **Triage figure-heavy sources** (slide decks, surveys — Janowicz's keynote yielded 78). Don't view all exhaustively. First let `pdf2md --min-figure-size` drop the icon/fragment noise (a slide deck has many sub-200 px crops that aren't real figures). Then view a representative sample plus *every* outlier (the smallest survivors, anything that looks blank/garbled). If the deck is large and the figures are the content, fan out parallel reviewers (one per batch of figures) rather than serializing.
3. **Caption completeness.** Figures that came through as a bare `Figure N` placeholder usually have a real caption nearby in the body ("Fig. N. …"). Attach it.
4. **Coverage.** Sanity-check that the page count, section range, references, and figure count are plausible for the source — a 30-page paper that yielded 3 pages of text lost something.

## Escalation policy: auto-fix the mechanical, surface the judgment

Fix the deterministic problems yourself and report them; stop and ask only when judgment is genuinely required.

**Auto-fix (then note in the report):**
- Marginal figure → re-run `pdf2md … --scale 3` (or higher) and re-view; sharper edge labels usually resolve it.
- Garbled text that looks scanned (no usable text layer) → re-run with `--ocr-engine ocrmac` (macOS native) and compare.
- `Figure N` placeholder → fill from the nearby body caption.
- An obvious, unambiguous first-page header merge → re-flow it into title / authors / abstract / keywords.

**Surface to the human (don't guess):**
- A figure still illegible after a scale bump (may need the vector original or a VLM OCR engine).
- Reading order you can't confidently reconstruct.
- Suspected missing pages or figures (coverage looks wrong and you can't explain it).

## Output

1. The reviewed `sources/<slug>.md` with fixes applied and image links/captions correct.
2. `figures_reviewed:` rewritten with the verdict — e.g. `"9/9 legible at scale 2; no escalation"` or `"fig-04 re-rendered at scale 3; fig-07 flagged illegible (needs vector original)"`.
3. A short **sanity report** to the human: what was checked, what was auto-fixed, what is flagged.

Do **not** write the synthesis here. A trustworthy `source-text` is the deliverable; the caller resumes at Checkpoint 2 (framing) and step 6 (synthesis) of the ingest.

## See also

- [memory-architecture.md](memory-architecture.md) — the full source-first ingest this plugs into
- [verification-gate.md](verification-gate.md) — the pre-commit gate (applies to the synthesis, later)
