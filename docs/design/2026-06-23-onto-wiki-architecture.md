# onto-wiki — Architecture & Build Design

> Design doc for the onto-wiki expertise-memory system. Status: approved in
> conversation 2026-06-23; building in stages from here.

## 1. Purpose

onto-wiki is an **expertise-based memory system** — "Chuck-in-a-box." Its job is to let an
agent doing ontology, knowledge-graph, and neurosymbolic work act with encoded expert
judgment: best practices, methodology, and *how the pieces fit together for actually
performing the operations* — grounded in primary sources so the guidance stays honest.

It is opinionated. RDF/OWL/SHACL are the substrate, not a menu of choices. The expertise
layer is the point; the literature is the evidence substrate underneath it.

## 2. Three content layers (depth)

1. **Primary sources** (`sources/`) — verbatim, faithful local renderings of the
   literature, with figures. Ground truth. An agent drops here for evidence when a
   synthesis claim must be checked. Not in the linked graph; reached by file read +
   section anchor.
2. **Source synthesis** — one wiki page per source: our reading, grounding *down* into the
   verbatim text by section anchor and figure path.
3. **Expertise layer ("Chuck-in-a-box")** — method/playbook, concept, and decision pages
   organized by the *operations* an agent performs. The layer an agent consults to act; it
   grounds down through layer 2 into layer 1.

In CoALA terms: layer 3 is procedural + semantic expertise memory; layers 1–2 are the
grounding substrate that keeps it honest.

## 3. The expertise-layer map (three dimensions)

### Context pillars (the underlying system)

1. **Foundations** — RDF / OWL / SHACL substrate (RDF-first; a property graph is a
   projection generated from RDF, never a competing target). Includes emerging
   **RDF 1.2 / SHACL 1.2**.
2. **Knowledge Fabrics & Governance** — federated knowledge substrate; data mesh vs data
   fabric; RDF/SHACL as the data-governance layer (Heimsbakk); agentic knowledge fabric
   (Broda). Sub-area: **scientific data meshes & fabrics** (Federated Research Data Mesh,
   Beyvers FFDE, Bai self-driving labs), cross-linked to CI-Compass work.
3. **FAIR & Scientific Data** — FAIR data principles (Wilkinson, FAIR 2.0); FAIR ontologies
   & vocabularies (Poveda, Garijo, Cox); persistent identifiers via linked structured data
   (McMurry); linking out to scientific data.
4. **Provenance & Trust** — PROV-O; trust envelopes (Verborgh); provenance in agentic
   systems, with RDF 1.2 triple terms / `rdf:reifies` as the statement-level mechanism.

### Operations (how-to playbooks)

- **A · Build (ODP/MOMo):** A1 model a domain with ODPs · A2 the MOMo workflow ·
  A3 elicit patterns with domain experts (GeoVoCamp)
- **B · Ground & validate:** B1 validate a KG with SHACL shapes (OBQC = one early instance) ·
  B2 FAIRify an ontology/vocabulary
- **C · Neurosymbolic / LLM-assisted:** C1 ground an LLM with an ontology to cut
  hallucination · C2 compose a neurosymbolic system (boxology) · C3 use LLMs across the OE
  lifecycle (41-task taxonomy)

### Reference shelf (materials & instruments operations point into)

- **Standards** — W3C stack: RDF/OWL/SHACL/SPARQL/PROV-O/GeoSPARQL/JSON-LD/DCAT/SKOS. Each
  page = opinionated digest + grounding pointer into the spec.
- **Reusable mid-level ontologies** — SOSA/SSN, PROV-O, QUDT, schema.org, GeoSPARQL, SKOS.
  Each page: what it covers, when to reuse, how it composes with ODPs.
- **Tools & frameworks** — Oxigraph, RDFLib, Comunica, kglab, pySHACL, CoModIDE, maplib,
  chrontext. Each page: what it's for, where it fits in an operation, a minimal example.

Top-level branching stays inside the Fano bound (≤12): 4 context pillars + 3 operation
families + 3 shelf categories, each with ≤5 children.

## 4. Page types

Adds to the SCHEMA's existing set (`concept`, `entity`, `source-summary`, `synthesis`,
`analysis`, `decision`, `index`, ...):

- **`source-text`** — a verbatim primary source in `sources/`. Provenance header
  (title, authors, year, ids, `source_url`, `html_source`, `retrieved`, `conversion`,
  `figures_reviewed`). Body is the faithful rendering; **do not edit**. Cited by section
  anchor + figure path. Lives outside the linked graph.
- **`method` / `playbook`** — a layer-3 operation page. Required sections:
  *When to use · Preconditions/inputs · Procedure · Pitfalls · Grounding (sources) ·
  Worked example.*

## 5. Edge vocabulary additions

Three new typed edges (operation contracts, preferred over `related:`):

| Edge | Inverse | Licenses the agent to… |
|---|---|---|
| `usesTool:` | `usedBy` | reach for this instrument to instantiate/test the operation |
| `reuses:` | `reusedBy` | leverage this existing ontology/material rather than reinvent |
| `governedBy:` | `governs` | treat the target standard/shape as the constraint regime |

Existing set retained: `up / source / extends / supports / criticizes / concept /
dependsOn / partOf / defines / ...`.

## 6. Ingestion pipeline (source-first, review-gated)

The governing principle: the **verbatim local source is built and reviewed before the
synthesis is written**, so the synthesis is composed from local ground truth, not transient
web-reading.

1. **Acquire & decide path** — locate source; choose HTML-first (arXiv) vs PDF→OCR
   fallback. **Checkpoint 1: confirm source + acquisition path before fetching.**
2. **Convert → verbatim `sources/` file** — deterministic; stable section anchors;
   provenance header. No interpretation.
3. **Pull figures → `sources/assets/<slug>/`** with captions preserved.
4. **Figure-resolution review** — view each figure, judge legibility; escalate (vector
   e-print tarball / higher-DPI / OCR re-extract) in-loop if any fail; record verdict in
   `figures_reviewed:`.
5. **Read verbatim text + figures; discuss framing.** **Checkpoint 2: approve framing
   before the synthesis is written.**
6. **Write the synthesis page** — grounds down by section anchor + figure path.
7. **Verification gate** — claims checked against the local verbatim text, not memory.
8. **Wire in** — index, cross-refs, log entry.
9. **Commit** — three units: (1) verbatim source + assets, (2) synthesis + index +
   cross-refs, (3) log entry on its own (one-commit-per-log-entry discipline).

This replaces the stock `/wiki-source` order of operations.

## 7. Acquisition & conversion tooling

- **HTML-first (proven)** — arXiv native HTML → `pandoc` (gfm) for a deterministic,
  faithful rendering (not an LLM paraphrase). Figures are downloaded from the HTML's
  `<figure>` assets (often SVG, vector) into `sources/assets/<slug>/`, links rewritten to
  local relative paths, captions preserved. Highest figure fidelity available via the arXiv
  e-print source tarball when a raster figure fails review.
- **PDF fallback** — for sources with no good HTML (e.g. MOMo / Shimizu 2022, only PDF).
  Source PDFs come from Paperpile (`~/Library/CloudStorage/GoogleDrive-…/My Drive/Paperpile/`,
  mirrored into the vault at `03 - Resources/Literature/Paperpile-PDFs/`). Conversion +
  image extraction is non-trivial; candidate stack: **DeepSeek OCR** for image-heavy /
  scanned pages, plus a structured PDF→markdown converter (docling / marker class). Python
  tools installed locally via **`uv`**. **Reference: an LA3D sample repo that already does
  PDF→markdown + image extraction (pointer pending).**
- Code fences in the verbatim source are language-tagged (`sparql`, `turtle`) by content;
  pseudo-notation and prompt templates left plain.

## 8. Build sequence

1. **Skeleton** — encode this map as Home/index + MOC/index stubs for the four context
   pillars, three operation families, three shelf categories; apply SCHEMA additions
   (page types, edge vocabulary, `sources/` layer, figure-review, two-checkpoint flow);
   update `/wiki-source` to the source-first procedure.
2. **Wire in the proven pilot** — the Allemang/OBQC source (HTML path, already built) lands
   under C1/B1, with its pre-agentic dating caveat.
3. **Flagship: A2 (MOMo workflow)** — exercises the PDF→OCR fallback on the Shimizu 2022
   PDF; high-meat, dense, figure-bearing. Validates the hard path end-to-end.
4. **Incremental growth** — pillars and playbooks fill in over time; the skeleton makes
   them discoverable from day one.

## 9. Open items

- **LA3D PDF-conversion reference repo** — identify it; it sets the docling/DeepSeek-OCR
  approach for the PDF path.
- **Exact PDF tool selection** — confirm DeepSeek OCR vs docling/marker after seeing the
  LA3D repo and testing on the MOMo PDF.
- **`defuddle`** and any other extraction helpers — install via `uv` as needed.
