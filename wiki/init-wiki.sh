#!/usr/bin/env bash
#
# init-wiki.sh — Bootstrap or update an LLM-maintained wiki for any project.
#
# Usage:
#   ./init-wiki.sh                        # Auto-detects repo name, uses wiki/ directory
#   ./init-wiki.sh --name "My Project"    # Custom project name
#   ./init-wiki.sh --github               # Clone the GitHub wiki repo instead of creating locally
#
# Modes:
#   Create — wiki doesn't exist yet. Creates all files from scratch with
#            namespaced navigation files for Obsidian compatibility.
#   Update — wiki exists. Adds missing sections to SCHEMA and CLAUDE.md
#            without overwriting existing content.
#
# Navigation files are namespaced to avoid collisions when multiple wikis
# share an Obsidian vault:
#   Home_${REPO_NAME}.md, index_${REPO_NAME}.md, log_${REPO_NAME}.md,
#   SCHEMA_${REPO_NAME}.md
#
# Home.md is kept as a redirect for GitHub wiki compatibility.
#
# ─── FOR THE LLM ──────────────────────────────────────────────────────────────
# If a user gave you the path to this script, EXECUTE it — do NOT reimplement
# it manually. It is idempotent: safe to re-run on existing wikis (auto-detects
# create vs. update mode).
#
# Before running, if llm-wiki.md exists at the repo root, read it for context
# on the underlying pattern (compounding wiki vs. RAG; LLM owns the wiki layer;
# Obsidian + LLM workflow). This shapes judgment calls during the first ingest.
#
# After it completes successfully, perform the first ingest:
#   1. Read the project README and any key docs the user points you to.
#   2. Create initial concept/entity pages per wiki/<repo>.wiki/SCHEMA_<repo>.md.
#   3. Add the new pages to index_<repo>.md and append a log_<repo>.md entry.
#
# Flags:
#   --name "Display Name"   custom project name (default: repo name)
#   --github                clone an existing GitHub wiki instead of init'ing locally
#   --agent "name"          coding assistant running this (e.g. claude-code,
#                           cursor); recorded in the create log entry's by: line
# ──────────────────────────────────────────────────────────────────────────────
#

set -euo pipefail

# --- Parse arguments ---
PROJECT_NAME=""
USE_GITHUB=false
WIKI_AGENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --name) PROJECT_NAME="$2"; shift 2 ;;
        --github) USE_GITHUB=true; shift ;;
        --agent) WIKI_AGENT="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Detect project info ---
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPO_NAME=$(basename "$REPO_ROOT")

if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME="$REPO_NAME"
fi

# --- Attribution: who is performing this operation ---
# The human is read from git config (never invented). The agent is whatever
# the caller passed via --agent. See the Log Entry Attribution section of the
# generated SCHEMA for the convention.
WIKI_USER=$(git config user.name 2>/dev/null || echo "unknown")
if [[ -n "$WIKI_AGENT" ]]; then
    BY_LINE="- by: ${WIKI_USER} via ${WIKI_AGENT}"
else
    BY_LINE="- by: ${WIKI_USER}"
fi

WIKI_DIR="$REPO_ROOT/wiki/${REPO_NAME}.wiki"

# Namespaced file names
HOME_NS="Home_${REPO_NAME}"
INDEX_NS="index_${REPO_NAME}"
LOG_NS="log_${REPO_NAME}"
SCHEMA_NS="SCHEMA_${REPO_NAME}"

# --- Detect mode ---
if [[ -f "$WIKI_DIR/${SCHEMA_NS}.md" ]] || [[ -f "$WIKI_DIR/SCHEMA.md" ]]; then
    MODE="update"
    echo "Existing wiki detected at $WIKI_DIR — running in update mode."
else
    MODE="create"
    echo "No wiki found — creating new wiki at $WIKI_DIR."
fi

# --- Helper: append a section to a file if a marker string is absent ---
append_section_if_missing() {
    local file="$1"
    local marker="$2"
    local content="$3"
    if [[ -f "$file" ]] && grep -qF "$marker" "$file"; then
        return 1  # already present
    fi
    printf '\n%s\n' "$content" >> "$file"
    return 0  # added
}

# --- Create or clone wiki (create mode only) ---
if [[ "$MODE" == "create" ]]; then
    if $USE_GITHUB; then
        REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
        if [[ -z "$REMOTE_URL" ]]; then
            echo "Error: No git remote 'origin' found. Can't derive GitHub wiki URL."
            exit 1
        fi
        WIKI_URL=$(echo "$REMOTE_URL" | sed 's/\.git$/.wiki.git/')
        echo "Cloning GitHub wiki from $WIKI_URL ..."
        mkdir -p "$REPO_ROOT/wiki"
        git clone "$WIKI_URL" "$WIKI_DIR" 2>/dev/null || {
            echo "Could not clone wiki. You may need to create the wiki on GitHub first"
            echo "(go to the repo → Wiki tab → create a page → save)."
            echo "Falling back to local initialization..."
            USE_GITHUB=false
        }
    fi

    if ! $USE_GITHUB; then
        mkdir -p "$WIKI_DIR"
        if [[ ! -d "$WIKI_DIR/.git" ]]; then
            git -C "$WIKI_DIR" init
            echo "Initialized local wiki repo at $WIKI_DIR"
        fi
    fi
fi

# --- Write Home_${REPO_NAME}.md (create only — never overwrite) ---
if [[ ! -f "$WIKI_DIR/${HOME_NS}.md" ]]; then
cat > "$WIKI_DIR/${HOME_NS}.md" << HOMEEOF
---
type: index
up: "[[WIKI-INDEX]]"
---

# ${PROJECT_NAME}

Welcome to the project wiki. This is an LLM-maintained knowledge base that grows as the project evolves.

## Navigation

- **[Index](${INDEX_NS})** — Full catalog of all wiki pages
- **[Log](${LOG_NS})** — Chronological record of wiki updates

## Categories

<!-- As top-level categories emerge in ${INDEX_NS}.md, mirror their
     headers here with 1-3 representative links per category. This is a
     curated human-facing nav surface, not a comprehensive catalog —
     leave that to the Index. -->

*No categories yet. Add them here as the wiki grows.*

## Getting Started

Ask your LLM to ingest key project documents:

> "Read the README and any key docs, then build out the wiki with concept pages, entity pages, and cross-references."

See [SCHEMA](${SCHEMA_NS}) for wiki conventions and maintenance workflows.
HOMEEOF
fi

# --- Write Home.md redirect (GitHub wiki landing page) ---
if [[ ! -f "$WIKI_DIR/Home.md" ]] || ! grep -qF "redirect" "$WIKI_DIR/Home.md" 2>/dev/null; then
cat > "$WIKI_DIR/Home.md" << REDIRECTEOF
<!-- redirect: this file exists for GitHub wiki compatibility -->
<!-- The real home page is ${HOME_NS}.md -->
See [${PROJECT_NAME}](${HOME_NS})
REDIRECTEOF
fi

# --- Write index_${REPO_NAME}.md (create only — never overwrite) ---
if [[ ! -f "$WIKI_DIR/${INDEX_NS}.md" ]]; then
cat > "$WIKI_DIR/${INDEX_NS}.md" << INDEXEOF
---
type: index
up: "[[${HOME_NS}]]"
---

# Index — ${PROJECT_NAME}

Catalog of all wiki pages, organized by category.

## Overview
- [Home](${HOME_NS}) — Project summary and navigation

<!-- Add pages here as the wiki grows -->
INDEXEOF
fi

# --- Write log_${REPO_NAME}.md (create only — never overwrite) ---
if [[ ! -f "$WIKI_DIR/${LOG_NS}.md" ]]; then
cat > "$WIKI_DIR/${LOG_NS}.md" << LOGEOF
---
type: index
up: "[[${HOME_NS}]]"
---

# Log — ${PROJECT_NAME}

Chronological record of wiki activity.

## [$(date +%Y-%m-%d)] create | Wiki initialized
${BY_LINE}
- Created wiki structure with namespaced navigation files
- Ready for first ingest
LOGEOF
fi

# --- SCHEMA: thin domain pointer ---
# DIVERGENCE FROM UPSTREAM llm-wiki-memory-template: the operating model
# (page formats, page-type catalog, typed edges, the source-first ingest
# pipeline, figure review, KG topology-vs-content, commit/log discipline) is
# authored ONCE in the static, agent-agnostic wiki/agents/memory-architecture.md
# -- NOT duplicated into each wiki's SCHEMA. init-wiki writes only a thin
# namespaced pointer here. This eliminates the old dual-maintenance hazard
# (heredoc + append calls kept byte-identical). Edit memory-architecture.md
# for mechanics; do not re-add mechanics sections to the SCHEMA.
SCHEMA_TARGET="$WIKI_DIR/${SCHEMA_NS}.md"
if [[ ! -f "$SCHEMA_TARGET" ]] || grep -qF "## Edges as Interface Operations" "$SCHEMA_TARGET" 2>/dev/null; then
    [[ -f "$SCHEMA_TARGET" ]] && echo "Migrating fat SCHEMA -> thin pointer" || echo "Writing thin SCHEMA"
    cat > "$SCHEMA_TARGET" << SCHEMAEOF
---
type: reference
up: "[[${HOME_NS}]]"
---

# Wiki Schema — ${PROJECT_NAME}

> This wiki holds **linked-data domain knowledge**. It does not carry its own operating manual.

## How this wiki is maintained

The operating model — page formats, the page-type catalog, typed edges, the source-first review-gated ingest pipeline, figure review, KG topology-vs-content, and commit/log discipline — is **agent-agnostic** and lives in \`wiki/agents/memory-architecture.md\` (repo-relative). Every harness overlay references it rather than copying. The typed-edge vocabulary is [Edge-Types](Edge-Types).

> **Maintainer note.** This SCHEMA is intentionally thin; \`wiki/init-wiki.sh\` authors the mechanics into \`wiki/agents/memory-architecture.md\`, not here. Do not re-add mechanics sections.

## Navigation files (namespaced)

- \`${INDEX_NS}.md\` — catalog of all pages by category; update on every ingest
- \`${LOG_NS}.md\` — append-only chronological record; one commit per entry; first bullet \`- by: <git config user.name> via <agent>\`
- \`${HOME_NS}.md\` — human-facing entry: charter + a Categories section mirroring the index's top-level categories
- \`Home.md\` — GitHub-wiki redirect only; do not edit
SCHEMAEOF
    echo "Wrote thin SCHEMA (mechanics in wiki/agents/memory-architecture.md)"
else
    echo "SCHEMA already thin — no change."
fi

# --- Stamp wiki/*.md.template files into the wiki ---
# Each *.md.template alongside this script gets sed-substituted (same
# placeholders as scripts/instantiate.sh: {{REPO_NAME}}, {{PROJECT_NAME}})
# and written into the wiki sub-repo with the .template suffix stripped.
# Idempotent on update mode: re-stamping overwrites with the same content.
SCRIPT_DIR_INIT="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_STAMPED=()
shopt -s nullglob
for tpl in "$SCRIPT_DIR_INIT"/*.md.template; do
    out_name="$(basename "${tpl%.template}")"
    out_path="$WIKI_DIR/$out_name"
    sed -e "s|{{REPO_NAME}}|${REPO_NAME}|g" \
        -e "s|{{PROJECT_NAME}}|${PROJECT_NAME:-$REPO_NAME}|g" \
        "$tpl" > "$out_path"
    TEMPLATES_STAMPED+=("$out_name")
done
shopt -u nullglob

if [[ ${#TEMPLATES_STAMPED[@]} -gt 0 ]]; then
    echo "Stamped wiki page templates:"
    for t in "${TEMPLATES_STAMPED[@]}"; do
        echo "  + $t"
    done
fi

# --- WIKI-INDEX: recursive registration ---
# Walk up from the wiki directory, creating/updating WIKI-INDEX files
register_in_wiki_index() {
    local wiki_dir="$1"
    local wiki_name="$2"
    local home_page="$3"
    local description="$4"

    local parent_dir
    parent_dir="$(dirname "$wiki_dir")"
    local parent_name
    parent_name="$(basename "$parent_dir")"

    # Determine the index filename for this level
    # Top-level "wiki/" gets bare WIKI-INDEX.md
    # Sub-collections get WIKI-INDEX_${collection_name}.md
    local index_file
    if [[ "$parent_name" == "wiki" ]]; then
        index_file="$parent_dir/WIKI-INDEX.md"
    else
        index_file="$parent_dir/WIKI-INDEX_${parent_name}.md"
    fi

    # Create the index file if it doesn't exist
    if [[ ! -f "$index_file" ]]; then
        local index_basename
        index_basename="$(basename "$index_file" .md)"
        cat > "$index_file" << WIKIIDXEOF
---
type: index
---

# Wiki Index — ${parent_name}

## Wikis
- [[${home_page}]] — ${description}
WIKIIDXEOF
        echo "Created $index_file"
    else
        # Add entry if not already present
        if ! grep -qF "[[${home_page}]]" "$index_file"; then
            # Find the Wikis section and append, or just append
            if grep -qF "## Wikis" "$index_file"; then
                # Append after the Wikis heading (find line number, insert after)
                local line_num
                line_num=$(grep -n "## Wikis" "$index_file" | tail -1 | cut -d: -f1)
                sed -i '' "${line_num}a\\
- [[${home_page}]] — ${description}" "$index_file" 2>/dev/null || \
                sed -i "${line_num}a\\
- [[${home_page}]] — ${description}" "$index_file"
            else
                printf '\n## Wikis\n- [[%s]] — %s\n' "${home_page}" "${description}" >> "$index_file"
            fi
            echo "Registered ${wiki_name} in $(basename "$index_file")"
        else
            echo "$(basename "$index_file") already has entry for ${wiki_name}"
        fi
    fi

    # Recurse up: register this collection's index in the grandparent
    local grandparent_dir
    grandparent_dir="$(dirname "$parent_dir")"
    local grandparent_name
    grandparent_name="$(basename "$grandparent_dir")"
    local index_basename
    index_basename="$(basename "$index_file" .md)"

    # Stop recursion at repo root or if we've left the wiki/ tree
    if [[ "$grandparent_dir" == "$REPO_ROOT" ]] || [[ "$grandparent_dir" == "/" ]]; then
        return
    fi

    # Check if grandparent has a WIKI-INDEX to register in
    local grandparent_index
    if [[ "$grandparent_name" == "wiki" ]]; then
        grandparent_index="$grandparent_dir/WIKI-INDEX.md"
    else
        grandparent_index="$grandparent_dir/WIKI-INDEX_${grandparent_name}.md"
    fi

    if [[ -f "$grandparent_index" ]] || [[ "$grandparent_name" == "wiki" ]]; then
        # Register this collection in the grandparent
        if [[ ! -f "$grandparent_index" ]]; then
            cat > "$grandparent_index" << GPIDXEOF
---
type: index
---

# Wiki Index

## Collections
- [[${index_basename}]] — ${parent_name} wikis
GPIDXEOF
            echo "Created $grandparent_index"
        elif ! grep -qF "[[${index_basename}]]" "$grandparent_index"; then
            if grep -qF "## Collections" "$grandparent_index"; then
                local gp_line
                gp_line=$(grep -n "## Collections" "$grandparent_index" | tail -1 | cut -d: -f1)
                sed -i '' "${gp_line}a\\
- [[${index_basename}]] — ${parent_name} wikis" "$grandparent_index" 2>/dev/null || \
                sed -i "${gp_line}a\\
- [[${index_basename}]] — ${parent_name} wikis" "$grandparent_index"
            else
                printf '\n## Collections\n- [[%s]] — %s wikis\n' "${index_basename}" "${parent_name}" >> "$grandparent_index"
            fi
            echo "Registered ${parent_name} collection in $(basename "$grandparent_index")"
        fi
    fi
}

# Register this wiki in the WIKI-INDEX hierarchy
register_in_wiki_index "$WIKI_DIR" "$REPO_NAME" "$HOME_NS" "$PROJECT_NAME wiki"

# --- CLAUDE.md: create or update ---
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
CLAUDE_UPDATED=()

WIKI_SECTION="## Wiki

This project maintains a **persistent wiki** at \`wiki/${REPO_NAME}.wiki/\` (separate git repo) following the [llm-wiki pattern](https://github.com/tobi/llm-wiki). The wiki is an LLM-maintained, interlinked knowledge base that compounds over time.

**Read \`wiki/agents/memory-architecture.md\` before making wiki changes.** It is the agent-agnostic operating model: page formats, the page-type catalog, typed edges (\`Edge-Types\`), the source-first review-gated ingest pipeline, figure review, and the three operations:

- **Ingest**: After completing significant work, update the wiki (create/update pages, cross-references, \`${INDEX_NS}.md\`, \`${LOG_NS}.md\`).
- **Query**: When answering analytical questions, search the wiki first (\`${INDEX_NS}.md\` → relevant pages). File valuable answers as new pages.
- **Lint**: Periodically health-check for orphan pages, stale claims, missing cross-references, and missing frontmatter."

KG_SUBSECTION="### Knowledge Graph

The wiki's frontmatter and body links feed a knowledge graph pipeline (\`scripts/kg/\`) that produces a SPARQL-queryable RDF graph from wiki content. The pipeline runs in Python via rdflib and pyshacl; no separate server is required by default.

- **Rebuild**: \`./scripts/kg/build-graph.sh\` after wiki updates
- **Query (default)**: in-process via rdflib against \`scripts/kg/build/graph-full.ttl\`. Agent tool wrappers run SPARQL queries directly against the loaded graph object.
- **Query (optional)**: load \`graph-full.ttl\` into Apache Jena Fuseki for live multi-client query, agent-write via SPARQL UPDATE, or federation across wikis. rdflib talks to a Fuseki endpoint via \`SPARQLStore\` without changes to tool code.
- Typed edges in frontmatter (\`extends:\`, \`supports:\`, \`criticizes:\`) produce rich graph relationships
- Body cross-references (\`[text](Page-Name)\`) produce \`mentions\` edges
- Pages without frontmatter are included as \`untyped\` nodes — no data is lost"

if [[ -f "$CLAUDE_MD" ]]; then
    if ! grep -qF "## Wiki" "$CLAUDE_MD"; then
        printf '\n---\n\n%s\n' "$WIKI_SECTION" >> "$CLAUDE_MD"
        CLAUDE_UPDATED+=("Wiki section")
    else
        # Wiki section exists — check for missing content within it

        if grep -qF "missing cross-references." "$CLAUDE_MD" && ! grep -qF "missing frontmatter" "$CLAUDE_MD"; then
            sed -i '' 's/missing cross-references\./missing cross-references, and missing frontmatter./' "$CLAUDE_MD" 2>/dev/null || \
            sed -i 's/missing cross-references\./missing cross-references, and missing frontmatter./' "$CLAUDE_MD"
            CLAUDE_UPDATED+=("Updated Lint line to include frontmatter checks")
        fi

        if ! grep -qF "wiki/agents/memory-architecture.md" "$CLAUDE_MD"; then
            ARCH_LINE="**Read \`wiki/agents/memory-architecture.md\` before making wiki changes.** It is the agent-agnostic operating model (page formats, page types, typed edges, the source-first ingest pipeline, figure review, the three operations)."
            if append_section_if_missing "$CLAUDE_MD" "wiki/agents/memory-architecture.md" "$ARCH_LINE"; then
                CLAUDE_UPDATED+=("memory-architecture reference")
            fi
        fi
    fi

    if ! grep -qF "### Knowledge Graph" "$CLAUDE_MD"; then
        printf '\n%s\n' "$KG_SUBSECTION" >> "$CLAUDE_MD"
        CLAUDE_UPDATED+=("Knowledge Graph subsection")
    fi
else
    cat > "$CLAUDE_MD" << CLAUDEEOF
# CLAUDE.md

> Context file for AI assistants working on this project.

$WIKI_SECTION

$KG_SUBSECTION
CLAUDEEOF
    CLAUDE_UPDATED+=("Created CLAUDE.md with Wiki + Knowledge Graph sections")
fi

if [[ ${#CLAUDE_UPDATED[@]} -gt 0 ]]; then
    echo "Updated CLAUDE.md:"
    for s in "${CLAUDE_UPDATED[@]}"; do
        echo "  + $s"
    done
else
    echo "CLAUDE.md already up to date."
fi

# --- Commit changes in wiki repo ---
cd "$WIKI_DIR"
git add -A
if git diff --cached --quiet 2>/dev/null; then
    echo ""
    echo "No wiki changes to commit."
else
    if [[ "$MODE" == "create" ]]; then
        git commit -m "Initialize wiki with llm-wiki pattern (namespaced)" --quiet 2>/dev/null || true
    else
        git commit -m "Update wiki schema: frontmatter + KG support" --quiet 2>/dev/null || true
    fi
fi

# --- Log entry (update mode only) ---
if [[ "$MODE" == "update" ]]; then
    # Find the log file (namespaced or bare)
    if [[ -f "$WIKI_DIR/${LOG_NS}.md" ]]; then
        LOG_FILE="$WIKI_DIR/${LOG_NS}.md"
    elif [[ -f "$WIKI_DIR/log.md" ]]; then
        LOG_FILE="$WIKI_DIR/log.md"
    else
        LOG_FILE=""
    fi

    if [[ -n "$LOG_FILE" ]] && ! grep -qF "frontmatter convention" "$LOG_FILE"; then
        cat >> "$LOG_FILE" << EOF

## [$(date +%Y-%m-%d)] update | Added frontmatter convention
- Schema updated with standard YAML frontmatter format
- Lint rules now check for missing frontmatter
- Knowledge graph pipeline support added
EOF
        cd "$WIKI_DIR"
        git add "$(basename "$LOG_FILE")"
        git commit -m "Log: frontmatter convention update" --quiet 2>/dev/null || true
    fi
fi

# --- Summary ---
echo ""
if [[ "$MODE" == "create" ]]; then
    echo "✓ Wiki initialized at $WIKI_DIR"
    echo ""
    echo "Navigation files:"
    echo "  Home:   ${HOME_NS}.md (redirect: Home.md)"
    echo "  Index:  ${INDEX_NS}.md"
    echo "  Log:    ${LOG_NS}.md"
    echo "  Schema: ${SCHEMA_NS}.md"
    echo ""
    echo "Next steps:"
    echo "  1. Start a conversation with your LLM in this repo"
    echo "  2. Ask it to ingest your key documents into the wiki"
    echo "  3. The wiki will grow from there"
else
    echo "✓ Wiki updated at $WIKI_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Run a lint pass to add frontmatter to existing pages:"
    echo "     Tell your LLM: \"Lint the wiki — focus on adding frontmatter to pages that are missing it\""
    echo "  2. After frontmatter is in place, build the knowledge graph:"
    echo "     ./scripts/kg/build-graph.sh"
fi
echo ""
echo "If using GitHub wiki, push with:"
echo "  cd $WIKI_DIR && git push origin master"
