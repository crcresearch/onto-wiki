# /// script
# requires-python = ">=3.11"
# dependencies = ["docling>=2.106"]
# ///
"""pdf2md — PDF → faithful markdown + extracted figures, shaped for the wiki `sources/` layer.

Primary path is born-digital: Docling parses the embedded text layer (no OCR), which is
faithful and fast for digital PDFs (academic papers). For scanned/image PDFs pass
`--ocr-engine` to turn on an OCR engine (see --help for the engines registered in this
install; `ocrmac` is Apple's native Vision OCR, local on macOS).

Output:
  <out>/<slug>.md                 source-text markdown (provenance header, section anchors)
  <out>/assets/<slug>/fig-NN.png  extracted figures (figure order), captions inlined

Run:  uv run scripts/pdf-to-markdown/pdf2md.py <pdf> --slug <slug> --out <dir> [opts]
"""
import argparse, datetime, sys
from pathlib import Path

from docling.document_converter import DocumentConverter, PdfFormatOption
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.datamodel.base_models import InputFormat
from docling_core.types.doc import ImageRefMode
import importlib.metadata as _ilm

PLACEHOLDER = "<!--PDF2MD_FIGURE-->"


def build_converter(do_ocr, ocr_engine, scale):
    opts = PdfPipelineOptions()
    opts.do_ocr = do_ocr
    opts.generate_picture_images = True
    opts.images_scale = scale
    if do_ocr and ocr_engine:
        from docling.models.factories import get_ocr_factory
        fac = get_ocr_factory(allow_external_plugins=True)
        kinds = fac.registered_kind
        if ocr_engine not in kinds:
            sys.exit(f"--ocr-engine '{ocr_engine}' not registered. Available: {kinds}. "
                     f"(VLM engines like deepseek_ocr need an extra docling plugin.)")
        opts.ocr_options = fac.create_options(kind=ocr_engine)
    return DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)})


def frontmatter(a, do_ocr, ocr_engine, scale, n_figs):
    try: ver = _ilm.version("docling")
    except Exception: ver = "?"
    conv = f"docling {ver} (do_ocr={do_ocr}" + (f", ocr_engine={ocr_engine}" if ocr_engine else "") + f", images_scale={scale})"
    def fld(k, v): return f'{k}: "{v}"\n' if v else ""
    return (
        "---\n"
        "type: source-text\n"
        + fld("title", a.title)
        + fld("authors", a.authors)
        + (f"year: {a.year}\n" if a.year else "")
        + fld("arxiv", a.arxiv) + fld("doi", a.doi) + fld("source_url", a.source_url)
        + f'retrieved: "{datetime.date.today().isoformat()}"\n'
        + f'conversion: "{conv}"\n'
        + f'figures_reviewed: "pending — run the OCR sanity-check skill ({n_figs} figures)"\n'
        "---\n\n"
        "> **Primary source — verbatim.** Faithful local rendering; do not edit. "
        "Cite by section anchor and figure path.\n\n"
    )


def main():
    p = argparse.ArgumentParser(description="PDF -> markdown + figures for the wiki sources/ layer.")
    p.add_argument("pdf", type=Path)
    p.add_argument("--slug", required=True, help="Author-Year-Slug (file + assets dir name)")
    p.add_argument("--out", type=Path, required=True, help="output dir (e.g. the wiki sources/ dir)")
    p.add_argument("--scale", type=float, default=2.0, help="figure render scale (default 2.0)")
    p.add_argument("--ocr-engine", default=None,
                   help="enable OCR with this engine (scanned PDFs). e.g. ocrmac (macOS native). "
                        "Omit for born-digital (default, no OCR).")
    for f in ("title", "authors", "arxiv", "doi", "source-url"):
        p.add_argument(f"--{f}", default=None)
    p.add_argument("--year", type=int, default=None)
    a = p.parse_args()
    a.source_url = getattr(a, "source_url")

    if not a.pdf.is_file():
        sys.exit(f"PDF not found: {a.pdf}")
    do_ocr = a.ocr_engine is not None
    assets = a.out / "assets" / a.slug
    assets.mkdir(parents=True, exist_ok=True)

    print(f"Converting {a.pdf.name} (do_ocr={do_ocr}, scale={a.scale}) ...", file=sys.stderr)
    doc = build_converter(do_ocr, a.ocr_engine, a.scale).convert(a.pdf).document

    # Save figures in document order; capture captions.
    figs = []
    for i, pic in enumerate(doc.pictures, start=1):
        img = pic.get_image(doc)
        cap = (pic.caption_text(doc) or "").strip()
        if img is None:
            figs.append((None, cap)); continue
        fp = assets / f"fig-{i:02d}.png"
        img.save(fp)
        figs.append((f"assets/{a.slug}/fig-{i:02d}.png", cap))

    md = doc.export_to_markdown(image_mode=ImageRefMode.PLACEHOLDER, image_placeholder=PLACEHOLDER)
    parts = md.split(PLACEHOLDER)

    # Interleave figure refs into placeholder slots (document order).
    out_md, warn = [parts[0]], None
    if len(parts) - 1 != len(figs):
        warn = f"placeholder count {len(parts)-1} != figures {len(figs)}; appending figures at end"
    for idx, seg in enumerate(parts[1:]):
        if idx < len(figs) and figs[idx][0]:
            rel, cap = figs[idx]
            alt = cap or f"Figure {idx+1}"
            out_md.append(f"![{alt}]({rel})\n" + (f"\n*{cap}*\n" if cap else ""))
        out_md.append(seg)
    body = "".join(out_md)
    if warn:
        body += "\n\n<!-- pdf2md: " + warn + " -->\n"
        for rel, cap in figs[len(parts)-1:]:
            if rel: body += f"\n![{cap or 'Figure'}]({rel})\n"

    out_md_path = a.out / f"{a.slug}.md"
    out_md_path.write_text(frontmatter(a, do_ocr, a.ocr_engine, a.scale, len(figs)) + body, encoding="utf-8")

    print(f"✓ {out_md_path}  ({len(body.split())} words, {sum(1 for f in figs if f[0])} figures → {assets})", file=sys.stderr)
    if warn:
        print(f"⚠ {warn}", file=sys.stderr)


if __name__ == "__main__":
    main()
