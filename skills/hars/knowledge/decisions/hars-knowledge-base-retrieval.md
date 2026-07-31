---
title: hars retrieves from and saves back to the ./knowledge/ knowledge base
type: decisions
date: 2026-07-30
tags: [hars, knowledge-base, retrieval, workflow]
---

hars is wired as a **consumer** of the `save-to-knowledge-base` skill's output. The retrieval
loop:

- **Phase 0a (retrieve):** if `./knowledge/index.md` exists, the Coordinator reads the index,
  opens relevant entries (`decisions/`, `architecture/`, `conventions/`, gotchas), follows
  `[[slug]]` links, and distills a **Known Context** digest. If there is no `index.md`, it
  cleanly skips — the step is conditional on that observable predicate, not an unconditional
  rule with exemptions.
- **Thread it:** Known Context is recorded in the plan's `## Known Context` section, pasted
  into the Planner prompt (reuse existing architecture/interfaces; flag any contradiction of a
  recorded decision), and fed into each Executor's "Project Conventions & Known Gotchas."
- **Resume** re-reads the plan's Known Context and linked entries.
- **Phase 6 (save back):** after the plan is done, persist new decisions/architecture/gotchas
  via the `save-to-knowledge-base` skill, closing the loop so the next run retrieves them.

**Why:** so a run doesn't re-litigate settled decisions or contradict known
architecture/conventions. A recorded decision (e.g. "persistent data → Postgres") should be
honored, not re-asked.

**Evidence (functional test, 5/5):** with a seeded KB containing a Postgres decision, 3/3
Coordinators read it and did NOT re-ask the database — they recognized the decision named
"sessions" and treated Postgres as settled, only asking about genuinely-open items. With no
KB, 2/2 cleanly skipped 0a and appropriately DID ask about storage (no decision to defer to).
The two behaviors split exactly on KB presence — proof retrieval actually drives behavior.

Related: [[hars-bdd-single-source-of-truth]], [[validating-skill-changes-with-subagents]].
