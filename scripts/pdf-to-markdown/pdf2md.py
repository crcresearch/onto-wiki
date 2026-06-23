# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "docling>=2.106",
#   "pypdfium2",
#   "pillow",
#   "mlx-vlm==0.3.10; sys_platform == 'darwin' and platform_machine == 'arm64'",
#   "ocrmac; sys_platform == 'darwin'",
# ]
# ///
"""pdf2md — PDF → faithful markdown + extracted figures, shaped for the wiki `sources/` layer.

Two engines:
  --engine docling      (default) parse the embedded text layer (born-digital papers).
                        Faithful + fast; no OCR. `--ocr-engine ocrmac` turns on OCR for
                        scanned PDFs via Apple Vision (macOS).
  --engine deepseek-mlx DeepSeek-OCR-2 run locally on Apple Silicon (mlx-vlm). Vision OCR
                        with grounding: figures come from detection bounding boxes. Use for
                        scanned docs, or to compare figure extraction. Downloads ~1-2 GB on
                        first run.

Output:
  <out>/<slug>.md                 source-text markdown (provenance header, section anchors)
  <out>/assets/<slug>/fig-NN.png  extracted figures (document order), captions where available

Run:  uv run scripts/pdf-to-markdown/pdf2md.py <pdf> --slug <slug> --out <dir> [opts]
"""
import argparse, ast, datetime, re, sys
import importlib.metadata as _ilm
from pathlib import Path

DEEPSEEK_DEFAULT = "mlx-community/DeepSeek-OCR-2-8bit"
DET = re.compile(r"<\|ref\|>(?P<label>.*?)<\|/ref\|><\|det\|>(?P<b>.*?)<\|/det\|>", re.DOTALL)


def _norm2px(b, w, h):
    x1, y1, x2, y2 = b
    return (int(x1 / 1000 * w), int(y1 / 1000 * h), int(x2 / 1000 * w), int(y2 / 1000 * h))


def _collapse_line(line, min_period=4):
    """Collapse exact consecutive tandem repeats within a line (word-level).

    Some PDFs have a text layer drawn 3-4x; Docling faithfully extracts the repeats,
    so each paragraph/heading/code line becomes its base content repeated k times.
    We collapse a repeat only when the period is substantial (>= min_period words) OR
    it repeats >=3 times (catches short repeated headings), so genuine short natural
    repeats ('the the' as reps=2, period<min) are left intact. Greedy, smallest-period.
    """
    toks = line.split()
    n, out, i = len(toks), [], 0
    while i < n:
        found = False
        for p in range(1, (n - i) // 2 + 1):
            reps = 1
            while toks[i + reps * p : i + (reps + 1) * p] == toks[i : i + p]:
                reps += 1
            if reps >= 2 and (p >= min_period or reps >= 3):
                out.extend(toks[i : i + p]); i += reps * p; found = True; break
        if not found:
            out.append(toks[i]); i += 1
    return " ".join(out)


def dedup_body(md):
    """Apply tandem-repeat collapse line-by-line (preserves blank lines / structure)."""
    return "\n".join(_collapse_line(l) if l.strip() else l for l in md.split("\n"))


# ---------- engine: docling (born-digital text layer) ----------
def convert_docling(pdf, assets, slug, scale, min_size, ocr_engine):
    from docling.document_converter import DocumentConverter, PdfFormatOption
    from docling.datamodel.pipeline_options import PdfPipelineOptions
    from docling.datamodel.base_models import InputFormat
    from docling_core.types.doc import ImageRefMode

    opts = PdfPipelineOptions()
    opts.do_ocr = ocr_engine is not None
    opts.generate_picture_images = True
    opts.images_scale = scale
    if ocr_engine:
        from docling.models.factories import get_ocr_factory
        fac = get_ocr_factory(allow_external_plugins=True)
        if ocr_engine not in fac.registered_kind:
            sys.exit(f"--ocr-engine '{ocr_engine}' not registered. Available: {fac.registered_kind}")
        opts.ocr_options = fac.create_options(kind=ocr_engine)
    conv = DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)})
    doc = conv.convert(pdf).document

    PH = "<!--PDF2MD_FIG-->"
    figs, n = [], 0
    for pic in doc.pictures:
        img = pic.get_image(doc)
        cap = (pic.caption_text(doc) or "").strip()
        if img is None or min(img.size) < min_size:
            figs.append((None, cap)); continue
        n += 1
        img.save(assets / f"fig-{n:02d}.png")
        figs.append((f"assets/{slug}/fig-{n:02d}.png", cap))

    parts = (doc.export_to_markdown(image_mode=ImageRefMode.PLACEHOLDER, image_placeholder=PH)).split(PH)
    out = [parts[0]]
    for idx, seg in enumerate(parts[1:]):
        if idx < len(figs) and figs[idx][0]:
            rel, cap = figs[idx]
            out.append(f"![{cap or f'Figure {idx+1}'}]({rel})\n" + (f"\n*{cap}*\n" if cap else ""))
        out.append(seg)
    return "".join(out), n


# ---------- engine: deepseek-mlx (DeepSeek-OCR-2 on Apple Silicon) ----------
def convert_deepseek_mlx(pdf, assets, slug, scale, min_size, model_id):
    import pypdfium2 as pdfium
    from mlx_vlm import load, generate
    from mlx_vlm.prompt_utils import apply_chat_template
    from mlx_vlm.utils import load_config

    pdoc = pdfium.PdfDocument(str(pdf))
    pages = [pdoc[i].render(scale=scale).to_pil() for i in range(len(pdoc))]
    print(f"  loading {model_id} (first run downloads ~1-2 GB) ...", file=sys.stderr)
    # NOTE: mlx-vlm is pinned to 0.3.10 (deps) — newer mlx-vlm fails to load DeepSeek-OCR's
    # custom processor. Do NOT pass trust_remote_code=True: on 0.3.10 it forces the broken
    # transformers AutoProcessor path ("Unrecognized processing class"); the bare load() uses
    # mlx-vlm's own DeepSeek-OCR handling, which works. (transformers prints a one-time
    # "run custom code?" prompt; it auto-proceeds in non-interactive runs.)
    model, processor = load(model_id)
    cfg = load_config(model_id)
    # Official DeepSeek-OCR structured-output prompt. Custom variants are unsupported and
    # can trigger garbage; the grounding token still yields <|ref|>/<|det|> bboxes for figures.
    PROMPT = "<|grounding|>Convert the document to markdown."

    n = 0
    body = []
    for i, pil in enumerate(pages, 1):
        tmp = assets / f"_page_{i:03d}.png"
        pil.save(tmp)
        formatted = apply_chat_template(processor, cfg, PROMPT, num_images=1)
        # cropping/min_patches/max_patches = DeepSeek-OCR-2 dynamic resolution (mlx-vlm README).
        # WITHOUT these the default resolution mishandles dense pages -> catastrophic repetition loop.
        out = generate(model, processor, formatted, [str(tmp)], temp=0.0, max_tokens=4096,
                       verbose=False, cropping=True, min_patches=1, max_patches=6)
        text = getattr(out, "text", str(out))
        W, H = pil.size

        def repl(m):
            nonlocal n
            if m.group("label").strip() != "image":
                return ""  # strip non-image detection tags
            try:
                bbs = ast.literal_eval(m.group("b").strip())
            except Exception:
                return ""
            bbs = bbs if (bbs and isinstance(bbs[0], list)) else [bbs]
            refs = []
            for bb in bbs:
                crop = pil.crop(_norm2px(bb, W, H))
                if min(crop.size) < min_size:
                    continue
                n += 1
                crop.save(assets / f"fig-{n:02d}.png")
                refs.append(f"\n![Figure {n}](assets/{slug}/fig-{n:02d}.png)\n")
            return "".join(refs)

        body.append(DET.sub(repl, text))
        tmp.unlink(missing_ok=True)
    return "\n\n".join(body), n


def frontmatter(a, engine, ocr_engine, scale, n, model_id):
    try: dver = _ilm.version("docling")
    except Exception: dver = "?"
    if engine == "deepseek-mlx":
        conv = f"deepseek-mlx ({model_id}, images_scale={scale})"
    else:
        conv = f"docling {dver} (do_ocr={ocr_engine is not None}" + (f", ocr_engine={ocr_engine}" if ocr_engine else "") + f", images_scale={scale})"
    def f(k, v): return f'{k}: "{v}"\n' if v else ""
    return (
        "---\ntype: source-text\n"
        + f("title", a.title) + f("authors", a.authors)
        + (f"year: {a.year}\n" if a.year else "")
        + f("arxiv", a.arxiv) + f("doi", a.doi) + f("source_url", a.source_url)
        + f'retrieved: "{datetime.date.today().isoformat()}"\n'
        + f'conversion: "{conv}"\n'
        + f'figures_reviewed: "pending — run the OCR sanity-check skill ({n} figures)"\n'
        + "---\n\n"
        "> **Primary source — verbatim.** Faithful local rendering; do not edit. "
        "Cite by section anchor and figure path.\n\n"
    )


def main():
    p = argparse.ArgumentParser(description="PDF -> markdown + figures for the wiki sources/ layer.")
    p.add_argument("pdf", type=Path)
    p.add_argument("--slug", required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--engine", choices=["docling", "deepseek-mlx"], default="docling")
    p.add_argument("--scale", type=float, default=2.0)
    p.add_argument("--min-figure-size", type=int, default=200,
                   help="skip extracted figures whose smaller side is below this (px); drops icon/fragment noise")
    p.add_argument("--dedup", action="store_true",
                   help="collapse exact consecutive tandem repeats (for PDFs whose text layer is drawn 3-4x)")
    p.add_argument("--ocr-engine", default=None, help="docling engine only: turn on OCR (e.g. ocrmac on macOS)")
    p.add_argument("--model", default=DEEPSEEK_DEFAULT, help="deepseek-mlx model id")
    for fl in ("title", "authors", "arxiv", "doi", "source-url"):
        p.add_argument(f"--{fl}", default=None)
    p.add_argument("--year", type=int, default=None)
    a = p.parse_args()

    if not a.pdf.is_file():
        sys.exit(f"PDF not found: {a.pdf}")
    if a.ocr_engine and a.engine != "docling":
        sys.exit("--ocr-engine applies only to --engine docling")
    assets = a.out / "assets" / a.slug
    assets.mkdir(parents=True, exist_ok=True)

    print(f"Converting {a.pdf.name} [engine={a.engine}, scale={a.scale}, min_fig={a.min_figure_size}] ...", file=sys.stderr)
    if a.engine == "deepseek-mlx":
        body, n = convert_deepseek_mlx(a.pdf, assets, a.slug, a.scale, a.min_figure_size, a.model)
    else:
        body, n = convert_docling(a.pdf, assets, a.slug, a.scale, a.min_figure_size, a.ocr_engine)

    if a.dedup:
        before = len(body.split())
        body = dedup_body(body)
        print(f"  dedup: {before} -> {len(body.split())} words", file=sys.stderr)

    out_md = a.out / f"{a.slug}.md"
    out_md.write_text(frontmatter(a, a.engine, a.ocr_engine, a.scale, n, a.model) + body, encoding="utf-8")
    print(f"✓ {out_md}  ({len(body.split())} words, {n} figures → {assets})", file=sys.stderr)


if __name__ == "__main__":
    main()
