---
title: hars has a whole-system integration gate (Phase 6) before "done"
type: decisions
date: 2026-07-30
tags: [hars, integration, workflow]
---

hars must NOT mark a plan `done` from per-task passes alone. A mandatory **Phase 6 —
Integrate & Verify Whole** runs after every sub-task passes its own Evaluator: it runs the
project's Build cmd and full Test cmd across the WHOLE project, then actually drives the
assembled system to check every scenario listed under the plan's `## Integration Scenarios`.
Only then is the plan `done`.

**Why:** the Evaluator judges each sub-task **in isolation** against only that task's
scenarios. Cross-cutting behavior (e.g. an end-to-end "run the tool and see output" scenario
that spans parser + checker + CLI) is unverified by any single per-task eval. Without a
whole-system gate, all tasks can be individually `done` while the assembled program doesn't
actually work.

Mechanism support: the Planner tags scenarios that only hold once several tasks are assembled
as **Integration Scenarios** (still counted exactly once in Coverage Check, but re-verified as
a whole in Phase 6). Sub-tasks also declare `Depends on` / `Provides (public interface)` and
are executed in topological order, so a dependent task builds against real interfaces rather
than guesses — reducing integration surprises.

Status: added by design + coherence review; the gate itself was not behaviorally
pressure-tested (see [[validating-skill-changes-with-subagents]]).

Related: [[hars-bdd-single-source-of-truth]].
