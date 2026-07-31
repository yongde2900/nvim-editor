---
name: save-to-knowledge-base
description: Distill the current conversation into a persistent knowledge base under ./knowledge/, writing one Markdown file per fact and keeping index.md as the map to everything. Use whenever the user wants to capture, save, record, or archive what was discussed — "把這個寫進知識庫", "記下這個決定", "save this to the knowledge base", "把 context 存起來", "document what we figured out" — or refers to a knowledge/ folder or index.md. Trigger even when they don't name the folder, as long as the intent is to persist takeaways from this session for later reuse.
---

# Save to Knowledge Base

Capture durable knowledge from the current conversation into a project-local knowledge base at `./knowledge/`. The knowledge base is a set of Markdown files, each holding one self-contained piece of knowledge, plus an `index.md` that maps out every file grouped by type.

## Why this shape

The knowledge base is meant to be read *later*, often by a different session with none of this conversation's context. So each file must stand on its own, and `index.md` is the entry point — someone (human or Claude) scans the index, follows the link to the type they need, and reads a file that makes sense in isolation. If the index drifts out of sync with the files, the whole thing rots. Keeping index.md accurate is the single most important discipline here.

## Directory layout

```
knowledge/
├── index.md                 # the map — grouped by type, one line per file
├── decisions/
│   └── use-postgres-over-mongo.md
├── architecture/
│   └── auth-token-flow.md
└── <type>/
    └── <slug>.md
```

Types are **derived from the content**, not from a fixed list. Read what you're saving and pick the category that best describes it (e.g. `decisions`, `architecture`, `bugs`, `conventions`, `how-to`, `reference`, `glossary`). Reuse an existing type directory when one fits; create a new one only when nothing existing captures the knowledge. A type is a directory; the knowledge lives in files inside it.

## Workflow

Follow these steps each time you save.

### 1. Decide what's worth keeping

Extract the *durable* takeaways from the conversation — decisions made and their rationale, how something works, a gotcha that cost time, a convention agreed on, a useful reference. Skip anything that's only relevant to this session (transient debugging chatter, one-off commands) or that the codebase already records plainly. If the user pointed at something specific ("save *this*"), capture that; otherwise use judgment on what a future reader would thank you for.

Prefer **one fact per file**. If the conversation yielded several distinct pieces of knowledge, write several files rather than one sprawling document — small focused files are easier to find, link, and update.

### 2. Bootstrap the knowledge base if needed

If `./knowledge/` or `./knowledge/index.md` doesn't exist yet, create it. Seed `index.md` from the template in `references/index-template.md`.

### 3. Classify and write each file

For each piece of knowledge:

- Choose its **type** (see above) and ensure `knowledge/<type>/` exists.
- Choose a short, descriptive kebab-case **slug** for the filename (e.g. `retry-backoff-strategy.md`).
- If a file already covers this topic, **update it in place** rather than creating a near-duplicate.
- Write the file using the frontmatter format below.

Every knowledge file starts with YAML frontmatter, then the body:

```markdown
---
title: Human-readable title
type: <type>            # matches the directory name
date: 2026-07-30        # today's date, YYYY-MM-DD; use the real current date
tags: [tag-a, tag-b]    # optional, for search
---

The knowledge itself, written to be understood with no prior context.

For a decision, state what was decided AND why — the alternatives considered
and the reason this won matter as much as the conclusion.

Link related knowledge inline with [[slug]], e.g. see [[auth-token-flow]].
```

Write the body so it makes sense standalone. For decisions, always record the *why*, not just the *what* — the reasoning is the part a future reader can't reconstruct. Convert relative dates ("yesterday", "next sprint") to absolute dates.

### 4. Update index.md — never skip this

After writing or updating any file, reflect it in `index.md`. The index is grouped by type, with one line per file: a link and a short hook describing what's inside.

```markdown
## Decisions
- [Use Postgres over Mongo](decisions/use-postgres-over-mongo.md) — chose relational for transactional integrity

## Architecture
- [Auth token flow](architecture/auth-token-flow.md) — how access/refresh tokens are issued and rotated
```

When you add a new type, add a new `##` section for it. When you update an existing file, refresh its hook if the content changed meaningfully. Keep entries sorted sensibly (newest or alphabetical within a section — stay consistent with what's already there).

### 5. Report what you saved

Tell the user concisely which files you wrote or updated and under which types, so they can verify. For example: "Saved 2 entries — `decisions/use-postgres-over-mongo.md` and `architecture/auth-token-flow.md` — and updated index.md."

## Notes

- Default the knowledge base to `./knowledge/` in the current working directory. If the user names a different location, use that instead.
- Never overwrite an existing file blindly — read it first, then merge or update. Duplicates and lost content are the main failure modes.
- Keep files small and focused; split rather than pile on.
