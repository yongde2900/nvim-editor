# Skills

Symlinked into `~/.claude/skills/` by `init.sh` — one symlink per directory here, so a new
skill only needs a directory with a `SKILL.md`. This file is not a skill; the loop skips it.

## The hars family

Harness-Driven Development: a BDD spec and a dependency-ordered plan are approved by a human
once, then executed, graded, and verified against that spec. Six skills, split by **what they
are allowed to write** — which is also how they route.

| Skill | Does | Writes |
|------|------|------|
| **hars-plan** | Clarifies requirements, writes the Gherkin spec, spawns the Planner, holds both approval gates | Creates BDD + PLAN; the only skill that stamps `approved` |
| **hars-execute** | Runs the plan task by task: Executor (TDD) → fresh-context Evaluator → iterate | Task statuses, goal checkboxes, Iteration Log |
| **hars-verify** | Whole-project build + full suite + every Integration Scenario driven end-to-end | The only skill that stamps a plan `done`; persists knowledge |
| **hars-revise** | Changes an already-approved doc: rollback / amend / unstall / fork | Reopens to `draft`, appends `## Amendments`, closes forks as `superseded` |
| **hars-status** | Answers "where are we?" and lints the plan's state machine | **Nothing.** Read-only, always |
| **hars-grade** | Grades existing code against BDD scenarios with a fresh-context reviewer | **Nothing.** A grade is never a state transition |


Shared contracts, each normative in exactly one place:

- [`hars-plan/plan-format.md`](hars-plan/plan-format.md) — the PLAN file schema, both state machines, and the field-ownership table. Every skill links here instead of restating it.
- [`hars-plan/planner.md`](hars-plan/planner.md), [`hars-execute/executor.md`](hars-execute/executor.md), [`hars-execute/evaluator.md`](hars-execute/evaluator.md) — the three subagent prompt templates. `hars-grade` reuses the Evaluator template rather than copying it.

Two invariants worth not breaking:

1. **Only `hars-plan` writes `approved`** — consent has one source.
2. **Only `hars-verify` writes `done`** — every task passing is a different claim from the system working.

The design decisions behind all of this, with their reasoning, are in [`../knowledge/`](../knowledge/index.md).

## Other skills

| Skill | Does |
|---|---|
| **save-to-knowledge-base** | Distills a conversation into `./knowledge/` — one fact per file, `index.md` as the map. `hars-verify` invokes it to close the learning loop. |
