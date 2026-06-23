# Memory Architecture (agent-agnostic)

Canonical operating model for a wiki built on this template: how an agent stores, navigates, and grounds knowledge. Agent-agnostic — every harness overlay (Claude Code, Cursor, …) references this file rather than copying it, the same DRY pattern as [discipline-gates.md](discipline-gates.md) and [verification-gate.md](verification-gate.md).

This file is the *operating system*. The wiki itself holds *domain knowledge*; it does not carry its own operating manual. The per-wiki `SCHEMA_<repo>.md` is a thin pointer here plus the namespaced specifics (its own `index_`/`log_`/`Home_` file names).

## What this wiki is

An **expertise-based memory system**: it lets an agent act with encoded expert judgment — best practices, methodology, and how the pieces fit together for performing the operations — grounded in primary sources so the guidance stays honest. The agent writes and maintains all pages; the human curates sources, directs analysis, and asks questions.

## Three content layers

1. **Primary sources** (`sources/`) — verbatim, faithful local renderings of the literature, with figures. Ground truth. Reached by file read + section anchor (`sources/<slug>.md#section`) and figure path; *outside* the linked graph. The agent drops here for evidence when a synthesis claim must be checked. They exist because even reviewed synthesis carries residual hallucination.
2. **Source synthesis** — one page per source: our reading, grounding *down* into the verbatim text by section anchor and figure.
3. **Expertise layer** — `method`/`playbook`, concept, and decision pages organized by the *operations* an agent performs. The point of the wiki; it grounds down through layer 2 into layer 1.

## Navigation: progressive disclosure

`Home_<repo>` (charter + categories) → MOC / index (domain area) → individual page (detail). Never read a whole folder; route through the layers. Keep any index section's direct children bounded (≤ ~12) so routing stays reliable.

## Page format

1. **Title** — `# Page Name` (H1)
2. **Opening line** — one sentence on what the page is
3. **Body** — concise reference style; tables, prose, code blocks
4. **See also** — `[Display](Page-Name)` cross-references at the bottom

## Frontmatter

```markdown
---
type: <see catalog>
up: "[[Parent-Page]]"
tags: [topic-a, topic-b]
---
```

Required: `type:` (use `untyped` if unsure) and `up:`. Every page gets frontmatter — no exceptions. Frontmatter wikilinks use `[[Page-Name]]`; body cross-references use `[Display](Page-Name)`. Frontmatter feeds the KG pipeline.

Typed edge fields are defined in [Edge-Types](Edge-Types) (the vocabulary, stamped into each wiki). Populate the most specific edge you can justify; treat `related:` as a fallback.

## Page-type catalog

Most types need no required structure beyond the page format. These do:

- **`source-text`** — a verbatim primary source in `sources/`. Provenance header (`title`, `authors`, `year`, ids, `source_url`, `retrieved`, `conversion`, `figures_reviewed`). **Never edited** — corrections to *our reading* go on the synthesis page. Cited by section anchor + figure path.
- **`source-summary`** — per-source synthesis; grounds down into its `source-text`.
- **`method` / `playbook`** — a layer-3 operation page. Required sections: *When to use · Preconditions/inputs · Procedure · Pitfalls · Grounding (sources + reference-shelf via `usesTool:`/`reuses:`/`governedBy:`) · Worked example.*
- **`analysis`** — query-driven assessment. Sections: *Question · Context · Analysis · Conclusion · Open follow-ups.* Frontmatter `derived_from:` (the source pages).
- **`decision`** — design choice. Sections: *Question · Options considered · Decision · Rejected alternatives · Revisit triggers.* Frontmatter `decided_at: YYYY-MM-DD`; optional `superseded_by:`.
- Other (`concept`, `entity`, `synthesis`, `index`, `moc`, `comparison`, `untyped`) — page format only.

## Edges as interface operations

A typed edge is an interface contract: it tells the agent what *operation* to run on traversal, not merely "these are related." `extends:` inherits context; `supports:` aggregates evidence; `criticizes:` triggers contradiction detection; `source:` is a grounding check; `usesTool:` reaches for an instrument; `reuses:` leverages existing material; `governedBy:` is a constraint regime. Full vocabulary and inverses in [Edge-Types](Edge-Types). Inverses are materialised by the KG, never authored. Inline (Variant 1) annotations carry a per-mention edge: `[Theory X](Theory-X) ([*extends*](Edge-Types#extends))`.

## Ingest — source-first, review-gated

Governing principle: **build and review the verbatim source before writing the synthesis**, so the synthesis is composed from local ground truth, not transient reading.

1. **Acquire & decide path** — HTML-first (e.g. arXiv HTML → `pandoc`) or PDF fallback (→ OCR/converter; Python tools via `uv`). **Checkpoint 1: confirm source + path before fetching.**
2. **Convert → `sources/<slug>.md`** — deterministic; stable anchors; provenance header (`type: source-text`); language-tag code fences by content.
3. **Pull figures → `sources/assets/<slug>/`** with captions; rewrite links to local paths.
4. **Figure-resolution review** — *view* each figure; judge legibility; escalate in-loop (vector source / higher-DPI / OCR) if any fail; record in `figures_reviewed:`.
5. **Read verbatim text + figures; discuss framing.** **Checkpoint 2: approve framing before writing the synthesis.**
6. **Write the synthesis** (`source-summary`) — grounds down by anchor + figure; add a dating/context caveat where the source's framing is dated.
7. **Verification gate** — check every claim against the local verbatim text (see [verification-gate.md](verification-gate.md)).
8. **Wire in** — cross-references both directions; the index; any playbook that now `source:`s this.
9. **Commit in three units** — (1) verbatim source + assets, (2) synthesis + index + cross-refs, (3) the log entry on its own.

## Query

Read the index → relevant pages → synthesize with citations. File reusable answers back as `analysis` pages so explorations compound.

## Lint

Periodically check: orphans, dead links, stale claims, missing pages, missing cross-references, pages missing frontmatter, and `type: untyped` pages that can now be typed.

## Topology vs content (when to use the KG)

- **Topology** (*what connects to what* — multi-hop, rollups, hub detection): SPARQL over the KG build (`scripts/kg/`).
- **Content** (*what a page says* — definitions, numbers, quotes): direct file read.

Use the KG to find *where* to look, then file tools to read *what* it says.

## Commit & log discipline

Stage files by name; descriptive messages; **do not push unless asked** (when pushing the wiki sub-repo, follow [wiki-write-protocol.md](wiki-write-protocol.md)). **One commit per log entry**: commit pages/index first, then the `log_<repo>` entry on its own, so `git blame` on the log is a faithful per-entry record. Every log entry's first bullet is `- by: <git config user.name> via <agent>` (read the name; do not invent it).

## See also

- [Edge-Types](Edge-Types) — the typed-edge vocabulary
- [verification-gate.md](verification-gate.md) · [discipline-gates.md](discipline-gates.md) · [wiki-write-protocol.md](wiki-write-protocol.md)
