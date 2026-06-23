---
name: wiki-source
description: Ingest a new source into the wiki, source-first. Builds a faithful verbatim sources/ rendering (with local figures, resolution-reviewed) as ground truth, then writes a synthesis page that grounds down into it. Two human checkpoints.
---

A new external source has entered the project. The goal is **durable, grounded memory**: a faithful local copy of the primary material plus a synthesis that can always be checked against it. This wiki is opinionated and source-first — build the verbatim source *before* the synthesis, so the synthesis is written from local ground truth, not transient web-reading.

## What is "a source"

- A research paper, article, technical report, or thesis chapter
- A design document or position paper
- An external README, blog post, or specification the user wants to keep

This is the Ingest operation. It is **not** for filing our own experiment results — use `/wiki-experiment` for those.

## What to capture

- **The verbatim primary text** → `sources/<Author-Year-Slug>.md` (`type: source-text`), with stable section anchors and a provenance header. The body is faithful and **never edited**.
- **The figures** → `sources/assets/<Author-Year-Slug>/`, captions preserved, *resolution-reviewed*.
- **The synthesis** → a `source-summary` page (our reading) that grounds down into the verbatim text by section anchor and figure path.

## Procedure

Follow the source-first Ingest in `wiki/agents/memory-architecture.md`. Steps:

1. **Acquire & decide path.** Locate the source; choose **HTML-first** (arXiv HTML → `pandoc -t gfm`, deterministic and faithful) or **PDF fallback** (Paperpile PDF at `~/Library/CloudStorage/GoogleDrive-…/My Drive/Paperpile/` or the vault mirror → OCR/converter; install Python tools via `uv`). **CHECKPOINT 1 — confirm the source and acquisition path with the user before fetching.**
2. **Convert → `sources/<slug>.md`.** Deterministic conversion (not an LLM paraphrase). Provenance header: `type: source-text`, `title`, `authors`, `year`, ids (`arxiv`/`doi`), `source_url`, `html_source`, `retrieved`, `conversion`, `figures_reviewed`. Add a "Primary source — verbatim; do not edit" notice. Language-tag code fences (`sparql`, `turtle`) by content; leave pseudo-notation/prompts plain.
3. **Pull figures → `sources/assets/<slug>/`**, rewrite image links to local relative paths, keep captions.
4. **Figure-resolution review.** *View* each figure; judge legibility. If any fail, escalate in-loop (arXiv e-print vector tarball / higher-DPI / OCR re-extract). Record the verdict in `figures_reviewed:`.
5. **Read the verbatim text + figures; discuss framing.** **CHECKPOINT 2 — get the user's approval of the framing and cross-link targets before writing the synthesis.**
6. **Write the synthesis** (`source-summary`). Frontmatter: `up:` to the closest parent, `source:` to the canonical URL, `concept:`/`supports:`/`criticizes:` where clear. Body: opening line, contribution, methods/results relevant here, why-it's-here, and a **Primary source (verbatim, for grounding)** section pointing to `sources/<slug>.md#section` and figure paths. Where the source's framing is dated (e.g. pre-agentic), add an expertise-layer dating caveat.
7. **Verification gate.** Run `wiki/agents/verification-gate.md` over every page; check each synthesis claim **against the local verbatim text**, not memory. Do not commit until it passes.
8. **Wire in.** Fix cross-references both directions (`[[Page]]` frontmatter, `[Display](Page)` body); update `index_onto-wiki.md` under "Source summaries"; link the source from any [Operations](Operations) playbook that now `source:`s it.
9. **Append the log** entry `## [YYYY-MM-DD] ingest | Source title` to `log_onto-wiki.md`; first bullet `- by: <git config user.name> via claude-code` (read it, do not invent).
10. **Commit in three units** (wiki repo): (1) verbatim source + assets, (2) synthesis + index + cross-refs, (3) the log entry on its own. Do not push unless asked; when pushing, follow `wiki/agents/wiki-write-protocol.md`.
11. Optionally rebuild the KG: `./scripts/kg/build-graph.sh`.

A typical source ingest touches 5 to 15 pages.

## When to skip

- Too short or off-topic to justify a source-text page (a line in an existing page may do).
- Duplicates an existing source (update that page instead).
- The user has not actually asked for the source to enter memory.

## After running

Tell the user the verbatim source path, the figure-review verdict, the synthesis page, and which existing pages/playbooks now link to the new source.
