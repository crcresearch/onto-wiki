# pdf2md — PDF → markdown + figures (for the wiki `sources/` layer)

Converts a PDF to a faithful `source-text` markdown page plus extracted figures, shaped for the
source-first ingest pipeline (see `wiki/agents/memory-architecture.md`). Operating-system-layer
tooling; it produces *ground truth*, it does not interpret.

## Engines

**`--engine docling` (default) — born-digital.** Parses the embedded text layer (`do_ocr=False`).
Faithful and fast for digital PDFs (academic papers); ~30 s for a 30-page paper, no GPU, no model
downloads beyond Docling's layout models. This is the validated default. For *scanned* PDFs pass
`--ocr-engine ocrmac` (Apple Vision, local, no download). The Docling VLM OCR engines
(`deepseek_ocr`, `glm_ocr`, `dots_ocr`) require an extra Docling plugin not installed by default —
on macOS, prefer the dedicated `deepseek-mlx` engine below instead.

**`--engine deepseek-mlx` — DeepSeek-OCR-2 on Apple Silicon.** Vision OCR with grounding, run
locally via `mlx-vlm` (`mlx-community/DeepSeek-OCR-2-8bit`, ~1–2 GB on first run). Figures come from
the model's detection bounding boxes. Use for scanned docs, or to compare figure extraction with
Docling — on slide decks it tends to read titles as text and extract only real figures, where the
Docling layout parser crops every slide. Born-digital prose is still more faithfully captured by
Docling's text layer, so this is a deliberate alternative, not the default.

> **mlx-vlm is pinned to `0.3.10`** (in the script's deps). Newer mlx-vlm fails to load
> DeepSeek-OCR's custom processor. Do not pass `trust_remote_code=True` — it forces the broken
> transformers path. On first use transformers prints a one-time "run custom code?" prompt; it
> auto-proceeds in non-interactive runs (answer `y` if running by hand).

## Run

```bash
# born-digital (default)
uv run scripts/pdf-to-markdown/pdf2md.py <pdf> \
  --slug Author-Year-Slug --out <wiki>/sources \
  --title "..." --authors "A; B; C" --year 2022 \
  --doi "..." --arxiv "..." --source-url "..."

# scanned (Docling + Apple Vision):   --ocr-engine ocrmac
# DeepSeek-OCR-2 on Apple Silicon:    --engine deepseek-mlx
# drop icon/fragment figures:         --min-figure-size 200   (default)
# collapse duplicated text layer:      --dedup
```

`--dedup` collapses exact consecutive tandem repeats (word-level, line-local), for PDFs whose text layer is drawn 3–4× (Docling faithfully extracts the repeats). It is guarded to leave genuine short repeats intact. It does **not** catch *cross-line* duplication (copies split across separate lines) — rare, but when it happens the conversion needs manual review or a different engine.

`uv` resolves dependencies from the inline PEP 723 header on first run.

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
