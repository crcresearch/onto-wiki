# pdf2md — PDF → markdown + figures (for the wiki `sources/` layer)

Converts a PDF to a faithful `source-text` markdown page plus extracted figures, shaped for the
source-first ingest pipeline (see `wiki/agents/memory-architecture.md`). Operating-system-layer
tooling; it produces *ground truth*, it does not interpret.

## Pathway

- **Primary — born-digital (default):** Docling parses the embedded text layer (`do_ocr=False`).
  Faithful and fast for digital PDFs (academic papers); ~30 s for a 30-page paper, no GPU, no model
  downloads beyond Docling's layout models. This is the validated path.
- **Fallback — scanned/image PDFs:** pass `--ocr-engine <name>` to turn on OCR. Engines registered in
  this install: `auto, easyocr, ocrmac, rapidocr, tesseract, tesserocr, nemotron-ocr, kserve_v2_ocr`.
  On macOS, **`ocrmac`** (Apple Vision, local, no download) is the pragmatic choice. The VLM engines
  (`deepseek_ocr`, `glm_ocr`, `dots_ocr`) require an extra Docling plugin not installed by default.

## Run

```bash
uv run scripts/pdf-to-markdown/pdf2md.py <pdf> \
  --slug Author-Year-Slug --out <wiki>/sources \
  --title "..." --authors "A; B; C" --year 2022 \
  --doi "..." --arxiv "..." --source-url "..."
# scanned fallback:  --ocr-engine ocrmac
```

`uv` resolves Docling from the inline PEP 723 header on first run.

## Output

```
<out>/<slug>.md                  # source-text frontmatter + verbatim body, figure-NN refs inlined
<out>/assets/<slug>/fig-NN.png   # figures in document order, scale 2.0; captions inlined where Docling linked them
```

`figures_reviewed:` is written as `pending` — the OCR **sanity-check skill** does the figure-legibility
review, enriches missing captions, and flags reading-order issues (e.g. multi-column journal headers
that Docling may merge on the first page).

## Known limitations (handled downstream by the sanity-check skill)

- Caption association is partial (Docling only inlines captions it links; others get `Figure N`).
- First-page reading order on multi-column/proof PDFs can merge header + abstract + intro.
- Default figure scale is 2.0; bump `--scale` for dense schema diagrams with fine edge labels.
