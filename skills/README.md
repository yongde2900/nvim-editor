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

## The herd family

Cross-**project** work, over Herdr. Where hars coordinates tasks inside one repo, herd coordinates
repos — one agent per project, each in its own workspace, talking only through a file on disk.
Split the same way as hars: by **what they are allowed to write**.

| Skill | Does | Writes |
|---|---|---|
| **herd-sync** | Negotiates one interface contract between repos, holds the approval gate, dispatches an implementer per project, verifies the seams end-to-end | `CONTRACT.md` state; **never** a project's code — the implementers do that |
| **herd-survey** | Asks one question of N repos in parallel and aggregates the answers into one table | **Nothing outside `~/.claude/herd/`.** Read-only w.r.t. every project, always |

Shared contracts, each normative in exactly one place:

- [`herd-sync/contract-format.md`](herd-sync/contract-format.md) — the CONTRACT schema, both state machines, the field-ownership table.
- [`herd-sync/registry-format.md`](herd-sync/registry-format.md) — `~/.claude/herd/registry.md`: project name → path, build, test. Both herd skills read it.
- [`herd-sync/implementer.md`](herd-sync/implementer.md), [`herd-survey/surveyor.md`](herd-survey/surveyor.md) — the two dispatched-agent briefs. Delivered by path, not pasted into a prompt, so both sides can re-read them.

Two invariants worth not breaking:

1. **Only the human writes `approved`** — same reason as hars: consent has one source.
2. **Only a file on disk promotes a project to `delivered`** — never a terminal read. Agents run on the alternate screen, where finished output leaves no scrollback; grading on `agent read` means eventually grading a truncated fragment.

herd deliberately stops at each repo's door: an implementer decides for itself whether its slice
needs a full `hars` run or three edits and a test. herd only cares whether it delivered.

## Other skills

| Skill | Does |
|---|---|
| **save-to-knowledge-base** | Distills a conversation into `./knowledge/` — one fact per file, `index.md` as the map. `hars-verify` invokes it to close the learning loop. |
| **herdr** | Drive the Herdr session from inside a pane: layout, agents, output, waits. Not hand-written — generated verbatim by `herdr --skill` (0.8.2). Regenerate after a `herdr update` rather than editing it. It is the *capability* manual; `herd-sync` / `herd-survey` are the *workflows* built on top of it. |
