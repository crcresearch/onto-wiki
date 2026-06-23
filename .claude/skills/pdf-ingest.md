---
name: pdf-ingest
description: Convert a PDF source into a trustworthy verbatim source-text page (markdown + extracted figures) for the wiki sources/ layer, then sanity-check the conversion and figures before they become ground truth. Use whenever a PDF needs to enter the wiki as a source — a paper only available as PDF, a scanned document, a Paperpile PDF, or the PDF-fallback path of /wiki-source — even if the user just says "add this PDF", "ingest this paper", "convert this PDF for the wiki", or points at a PDF. Runs scripts/pdf-to-markdown/pdf2md.py (Docling) then the OCR sanity-check; stops at a verified source-text and hands back to /wiki-source for the synthesis.
---

This is the **PDF path** of the source-first ingest (see `wiki/agents/memory-architecture.md`). Its job is to produce a *trustworthy* `source-text` — the anti-hallucination ground truth that synthesis pages cite. It does **not** write the synthesis.

Born-digital PDFs (most academic papers) parse from their embedded text layer — faithful and fast, no OCR. Scanned PDFs need an OCR engine. The figures often carry the real content, so they get *seen* and reviewed, not assumed.

## Procedure

1. **Checkpoint 1 — confirm with the user before converting.** Which PDF (locate it; Paperpile lives at `~/Library/CloudStorage/GoogleDrive-…/My Drive/Paperpile/`, mirrored in the vault), the `Author-Year-Slug`, and the path: born-digital (default) or scanned (`--ocr-engine ocrmac`). Decide the destination `sources/` dir (`wiki/<repo>.wiki/sources`).

2. **Convert** with the bundled tool:
   ```bash
   uv run scripts/pdf-to-markdown/pdf2md.py "<pdf>" \
     --slug <Author-Year-Slug> --out wiki/<repo>.wiki/sources \
     --title "..." --authors "A; B; C" --year YYYY \
     --doi "..." --arxiv "..." --source-url "..."
   # scanned source: add  --ocr-engine ocrmac
   ```
   `uv` resolves Docling from the script's inline deps. Output: `sources/<slug>.md` (`figures_reviewed: pending`) + `assets/<slug>/fig-NN.png`.

3. **Sanity-check** — run the procedure in `wiki/agents/ocr-sanity-check.md`: view *every* figure for legibility, check text fidelity / reading-order / captions / coverage. **Auto-fix the mechanical** (re-run `--scale 3` for marginal figures, fill `Figure N` captions from nearby body text, re-flow an obvious first-page header merge, switch to `--ocr-engine ocrmac` if text is garbled) and report it. **Surface judgment calls** (a figure still illegible after a scale bump, reading order you can't reconstruct, suspected missing pages). Rewrite `figures_reviewed:` with the verdict and give the user a short sanity report.

4. **Hand back.** A trustworthy `source-text` now exists. Return to `/wiki-source` at Checkpoint 2 (framing) → synthesis. The `source-text` body is verbatim — only ever fix *conversion artifacts* (image paths, captions, reading order), never the prose.

## When to skip

- The source has clean HTML (e.g. arXiv) — `/wiki-source` uses the pandoc HTML path instead; it's higher-fidelity than converting the PDF.
- The PDF isn't entering the wiki as a durable source.
