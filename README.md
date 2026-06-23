# Onto-Wiki

<one-sentence description, edit me>

<!--
  This README was generated from README.md.template by
  scripts/instantiate.sh when the project was created from
  crcresearch/llm-wiki-memory-template. Placeholders substituted at
  instantiation time:
    Onto-Wiki   Human-readable project name.
    onto-wiki      Repository slug (used for the wiki path).
    crcresearch          GitHub owner / org (derived from origin URL).
    <one-sentence description, edit me>    Project description; default text below until edited.

  Edit this file freely once the project is up. The structure below is a
  suggestion, not a requirement; sections "This repository uses LLM wiki
  memory", "Quick start for collaborators", and "About the template" are
  what make this project legible to future contributors and to any AI
  coding assistant they bring along, so consider keeping them.
-->

## This repository uses LLM wiki memory

Onto-Wiki keeps a persistent, LLM-maintained knowledge base under `wiki/onto-wiki.wiki/` (a separate git repo), following the [llm-wiki pattern](https://github.com/tobi/llm-wiki). It is the project's durable memory: findings, decisions, experiment results, and intermediate insights belong in the wiki and accumulate over time. Three operations, **Query** (read it), **Ingest** (write to it), and **Lint** (health-check it), are codified in `CLAUDE.md`, in `wiki/onto-wiki.wiki/SCHEMA_onto-wiki.md`, and in the `.claude/commands/` slash commands (`/wiki-source`, `/wiki-experiment`, `/wiki-lint`).

See also [llm-wiki.md](llm-wiki.md) in this repo for the underlying pattern.

## Quick start for collaborators

New to Onto-Wiki? Clone the project repo, clone the wiki as a sibling sub-repo, then seed your local Claude Code memory:

```bash
git clone https://github.com/crcresearch/onto-wiki.git
cd onto-wiki
git clone https://github.com/crcresearch/onto-wiki.wiki.git wiki/onto-wiki.wiki
./wiki/agents/claude-code/setup.sh --seed-memory
```

After this, open Claude Code inside the repo. It will automatically pick up the project's slash commands (`/wiki-source` to ingest an external document, `/wiki-experiment` to file experiment results, `/wiki-lint` to health-check the wiki) along with the read/write/commit conventions in `CLAUDE.md`.

The wiki at `wiki/onto-wiki.wiki/` is a separate git repo with its own history and its own remote. After any wiki edit, commit in the wiki repo (not the project repo):

```bash
git -C wiki/onto-wiki.wiki add <files>
git -C wiki/onto-wiki.wiki commit -m "..."
```

Push the wiki only when you intend to publish the changes:

```bash
git -C wiki/onto-wiki.wiki push origin master
```

## About the template

This project was instantiated from [crcresearch/llm-wiki-memory-template](https://github.com/crcresearch/llm-wiki-memory-template). Maintainers who need to pull template updates, add a new agent overlay (Cursor, OpenCode, etc.), or understand the instantiate/update scripts should read the template repo's documentation.
