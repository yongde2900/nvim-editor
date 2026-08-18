---
name: hars-plan
description: Harness-Driven Development, planning half. Turns a feature request into an approved, self-contained development document pair — a Gherkin BDD spec plus a dependency-ordered PLAN file that hars-execute can later run unattended. Use this whenever the user says "hars", "hars plan", "hars mode", "harness workflow", "harness 規劃", or asks to spec/plan a feature with quality gates before implementation. Also use when the user wants BDD scenarios written, wants a feature decomposed into dependency-ordered sub-tasks with interface contracts, or wants a thorough spec-first workflow — even if they never say the word "harness". Do NOT use it to implement or run tasks (hars-execute), to change a plan that was already approved (hars-revise), or to report on existing plans (hars-status).
---

# Hars — Plan (Spec & Planning Half)

Produces the **development documents**. Implementation is a separate skill (`hars-execute`) that consumes what you write here.

**Role split:**
- **You = Coordinator** — retrieve relevant prior knowledge, clarify requirements with the user, fix the project toolchain, author the BDD spec, spawn the Planner, hold both approval gates. This file is your playbook.
- **Planner (model=opus)** — map the approved BDD scenarios into dependency-ordered sub-tasks with interface contracts, and write the plan file. Prompt template: [planner.md](planner.md)

Your deliverable is a pair of files that are **self-contained**: `hars-execute` starts with a fresh context and gets nothing except these two documents. Anything an implementer needs to know — toolchain, conventions, gotchas, interface contracts — must be written down here, not left in your head or in a knowledge base you happened to read.

## Trigger

User says: "hars", "hars plan", "hars mode", "harness workflow", "harness 規劃", or wants a thorough quality-gated spec before implementation.

If the user instead wants to **run** an already-approved plan ("hars run", "hars continue", "跑下一個 task"), that is `hars-execute` — hand off, don't re-plan.

## Workflow

```
Prompt
  → Phase 0  Retrieve knowledge (./knowledge/) + clarify requirements WITH the user + fix language / build / test / lint commands
  → Phase 1  Write BDD-NNN.feature (Gherkin), self-check scenario quality → present → ⛔ GATE 1: wait for approval
  → Phase 2  Spawn Planner → PLAN-NNN.md (scenarios → Expected Goals; tasks dependency-ordered, each with an interface contract) → present → ⛔ GATE 2: wait for approval
  → Phase 3  Mark the plan approved, hand off to hars-execute
```

⛔ **TWO mandatory human approval gates — Phase 1 (BDD) and Phase 2 (plan).** Each is a hard STOP: end your turn and wait for the user's word. Neither can be inferred, batched into the other, or skipped under time pressure. **Approving the BDD is NOT approving the plan** — the second gate is exactly as binding as the first.

These gates matter more here than in a single-skill design: once you stamp the plan `approved`, `hars-execute` will run it without asking anyone again. The approval stamp is the only thing standing between a half-baked plan and an unattended implementation loop.

---

## Phase 0 — Retrieve Knowledge, Clarify Requirements & Fix Toolchain

You talk to the user directly — do NOT spawn an agent for this.

### 0a — Retrieve prior knowledge (before asking anything)

If a knowledge base exists, mine it first so you don't re-litigate settled decisions or contradict known architecture/conventions:

```bash
cat ./knowledge/index.md 2>/dev/null
```

- If there is no `./knowledge/index.md`, skip this step — nothing to retrieve — and move on.
- Otherwise scan the index and open the entries relevant to this task — especially `decisions/`, `architecture/`, `conventions/`, and any `bugs`/gotchas touching the same area. Follow `[[slug]]` links between entries.
- Distill what you find into a short **Known Context** digest: relevant prior decisions (with their *why*), architecture/interfaces already in place, conventions to follow, and gotchas to avoid.

Carry this digest forward: it shapes your clarifying questions (confirm what the base already says — don't re-ask it), the BDD spec, and the Planner prompt.

> **You are the knowledge base's main reader, and the only one who reads it up front.** `hars-execute` consults it only opportunistically, when an Executor gets stuck on something unforeseen. So anything you already know matters must be **copied into the plan file as prose**, not left as a slug for someone to chase later. See Phase 2.

### 0b — Clarify & fix toolchain

Ask focused questions until you can describe the desired behavior concretely. Cover at least:
- **Actors & goal** — who uses this, what outcome do they want?
- **Happy path** — the main success flow, step by step.
- **Edge cases & errors** — empty input, invalid input, concurrency, failure modes.
- **Acceptance** — how will the user know it's correct? What's explicitly out of scope?

Stop asking once you have enough to write concrete Given/When/Then scenarios. Don't over-interrogate — if a default is obvious, state it and move on.

Also fix the project's **toolchain** now — these go in the plan header and `hars-execute` reuses them verbatim in every Executor, Evaluator, and verification step (this is what keeps hars language-agnostic):
- **Language / stack** — detect from the working dir if code already exists; otherwise ask.
- **Build / Test / Lint commands** — the exact commands for THIS project. Examples:
  - Go:      `go build ./...`  /  `go test -race ./<dir>/...`  /  `go vet ./<dir>/...`
  - Python:  `python -m compileall <dir>`  /  `pytest <dir>`  /  `ruff check <dir>`
  - TS/Node: `tsc -b`  /  `vitest run <dir>`  /  `eslint <dir>`
- **Project conventions** — error-handling style, state/cancellation model, etc. (pulled from the codebase, not hard-coded).

Get these right. A wrong test command doesn't surface as a question later — it surfaces as an Executor loop that can't tell passing from failing.

---

## Phase 1 — BDD Spec (you write the Gherkin, no subagent)

### 1a — Determine ID

Run once; the same NNN is reused for both the BDD and the plan file. Use the highest existing number + 1 (not a raw count — deletions leave gaps):

```bash
ls <working_dir>/plan/PLAN-*.md <working_dir>/bdd/BDD-*.feature 2>/dev/null \
  | grep -oE '(PLAN|BDD)-[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1
```

Next ID = that + 1, zero-padded to 3 digits (e.g. `003`). If nothing matches, start at `001`.

### 1b — Write the BDD file

Write `<working_dir>/bdd/BDD-NNN-<slug>.feature` using standard Gherkin. Each scenario must be a **measurable, testable behavior** — these scenarios become the Evaluator's grading standard, so avoid vague outcomes.

```gherkin
# BDD-NNN — <brief>
# Created: <YYYY-MM-DD>
# Status: draft
# Working Directory: <abs path>

Feature: <feature name>
  As a <role>
  I want <capability>
  So that <benefit>

  Scenario: <happy-path name>
    Given <precondition>
    When <action>
    Then <observable, checkable outcome>

  Scenario: <edge case>
    Given <precondition>
    When <action>
    Then <observable, checkable outcome>

  # add one Scenario per distinct behavior — happy paths, edges, and error paths
```

### 1b-check — Scenario quality gate (self-check before presenting)

These scenarios become the Executor's tests and the Evaluator's grading standard — garbage in, garbage out. Before presenting, verify EVERY scenario:

- [ ] Has all three of Given / When / Then.
- [ ] The **Then is observable and checkable** — a concrete outcome you could assert in a test (exit code, printed text, a count, a specific error message). Reject vague outcomes like "works correctly", "is fast", "handles it gracefully".
- [ ] Is independently testable — it does not rely on another scenario having run first.
- [ ] Covers a single distinct behavior — split any scenario that has multiple When/Then pairs.

Rewrite any scenario that fails a checkbox until it passes. Only then present it.

### 1c — GATE 1 of 2: User Confirmation (MANDATORY)

Present the scenarios and wait:

```
[hars] BDD-NNN ready for review.

Feature: <feature name>
Scenarios:
  1. <scenario name>
  2. <scenario name>
  ...

Reply "通過" / "go" / "ok" to lock the spec and start planning, or tell me what to change.
```

⛔ **Do NOT start Phase 2 until the user approves the BDD.** If the user requests changes, edit the `.feature` file and re-present. When approved, set the header `# Status: approved`.

---

## Phase 2 — Plan (spawn Planner, model=opus)

Spawn an `Agent` with `model: "opus"`. The Planner reads the approved BDD file, groups scenarios into sub-tasks, orders them by dependency, declares each task's interface contract, and writes the plan file with `Status: draft`. **Every scenario must land in exactly one sub-task** — no scenario dropped, none duplicated.

📄 **Planner prompt template → [planner.md](planner.md).** Open it, fill the `<...>` placeholders (BDD spec, Known Context digest, toolchain, working dir, plan file path, and the **absolute path to [plan-format.md](plan-format.md)**), and paste it as the Planner agent's prompt.

📐 The plan file's schema, its `Status` values, and who owns which field are defined once in **[plan-format.md](plan-format.md)** — `hars-execute` reads the same document. Consult it there rather than restating it; a format written down twice drifts, and the two halves only interoperate because they agree on these exact field names.

**Pass the Known Context digest as prose, not as slugs.** The Planner writes it into the plan file, and that copy is the only version `hars-execute` will ever see.

### 2b — Plan file ownership (read-only rule)

The plan file is shared mutable state between this skill and `hars-execute`, and once execution starts, `hars-execute` owns it: it rewrites task `Status:` fields, ticks off Expected Goals, and appends to the Iteration Log on every cycle. The full ownership table is in [plan-format.md](plan-format.md) §4.

> ⛔ **Only ever create a new plan file, or edit one whose header says `Status: draft`.**
> A plan marked `approved`, `in-progress`, `stalled`, or `done` is READ-ONLY to this skill.

Re-spawning the Planner over a plan that execution has already touched silently destroys the progress written into it — the task statuses and Iteration Log are the only record that work happened, and they live nowhere else.

If the user wants to change a plan that is no longer draft, that is **`hars-revise`** — invoke it rather than editing here. It picks one of four routes from the plan's actual state:

| Situation | `hars-revise` route |
|-----------|---------|
| Execution hasn't started (`approved`, all tasks `pending`) | **Rollback** — confirms no loop is running, flips the header back to `draft`, and hands it back to you to revise and re-present at Gate 2. |
| A `pending` task's interface or scope is wrong; behavior unchanged | **Amend** — a bounded in-place edit with its own confirmation gate and an append-only `## Amendments` audit trail. The plan stays `approved`. |
| Execution stopped on a blocker (`stalled`) | **Unstall** — reads the Iteration Log, requires a real change, then resets the task to `pending`. |
| The change is substantial, work is already `done`, or the BDD's behavior itself changes | **Fork** — a NEW BDD + plan pair at the next NNN (written by you, through both gates), with the old plan closed as `superseded`. History stays intact and the finished tasks keep their evidence. |
| Execution is underway (`in-progress`, loop live) | **STOP** — the loop must finish or be halted first. Never edit while another agent may be writing. |

Your part is unchanged either way: when a revision comes back to you as a `draft`, or as a fork to plan at the next NNN, you run the normal phases and gates. What you must not do is edit a non-draft plan in place because the change looked small.

Adding scenarios to an already-approved BDD has the same problem: the plan's Coverage Check no longer matches the spec, and `hars-execute` grades tasks against scenarios that were never planned into them. Treat spec changes after Gate 1 as a new NNN unless the plan is still draft.

### 2c — GATE 2 of 2: User Confirmation (MANDATORY)

After the Planner returns, read the plan file and present it:

```
[hars] PLAN-NNN ready for review.

Sub-tasks (dependency order):
  1. <Task 1 name>  (depends on: <none|tasks>) — covers scenarios: <names>
  2. <Task 2 name>  (depends on: <none|tasks>) — covers scenarios: <names>
  ...
Integration scenarios (re-checked whole by hars-verify at the end): <names>
Quality gates: pass threshold <X.X>/10, max <K> iterations per task <+ any per-task override>

Reply "go", "ok", or "proceed" to approve the plan for execution, or revise it first.
```

Present the quality gates every time — they are not boilerplate. They decide how strictly `hars-execute` grades and how long it keeps retrying before it stops and asks for help, and once the plan is approved nobody gets asked about them again.

⛔ **Do NOT stamp the plan approved until the user confirms.** This is a hard STOP, exactly as binding as the BDD gate. End your turn and wait for the user's word.

> - Do NOT infer plan approval from an earlier "go" on the BDD — **approving the spec is not approving the plan.**
> - Do NOT treat the deadline, "move fast", or "don't babysit this" as consent to skip.
> - Do NOT start implementing, or invoke `hars-execute`, to "get a head start" while waiting.
> - A user reply that only changes the plan is NOT approval — revise and re-present.

If the user requests changes, update the plan file (or re-spawn the Planner) and re-present.

---

## Phase 3 — Stamp & Hand Off

Only after the user approves at Gate 2:

1. Edit the plan file header: `Status: draft` → `Status: approved`.
2. Add `Approved: <YYYY-MM-DD>` under it.
3. Verify the plan is self-contained before handing off — re-read it and confirm:
   - [ ] Build / Test / Lint commands are concrete, not placeholders.
   - [ ] `Pass threshold` and `Max iterations` are present with real numbers, and match what the user just approved.
   - [ ] `## Known Context` holds actual prose (decisions, conventions, gotchas), not bare `[[slug]]` links.
   - [ ] Every task has `Depends on` and `Provides (public interface)` filled in.
   - [ ] Every task's `Status:` is `pending` — no other value is legal in a fresh plan (see [plan-format.md](plan-format.md) §3).
   - [ ] `## Coverage Check` has exactly one row per BDD scenario.
   - [ ] The BDD file header says `# Status: approved`.
   Fix anything that fails before handing off — `hars-execute` cannot ask you these questions later.
4. Report and stop:

```
[hars] PLAN-NNN approved — N sub-tasks, M scenarios.
Spec:  <working_dir>/bdd/BDD-NNN-<slug>.feature
Plan:  <working_dir>/plan/PLAN-NNN-<slug>.md

Ready to execute. Say "hars run" to start the implementation loop.
```

Do NOT begin implementing. Handing off is the end of this skill's job.

---

## Resume After Interruption

```bash
cat <working_dir>/bdd/BDD-NNN-<slug>.feature   # the spec and its status
cat <working_dir>/plan/PLAN-NNN-<slug>.md      # the plan and its status
cat ./knowledge/index.md 2>/dev/null           # re-orient in the knowledge base
```

- BDD header is not `# Status: approved` → resume at Phase 1 (re-present for Gate 1).
- BDD approved but no plan file → resume at Phase 2.
- Plan exists with `Status: draft` → resume at Gate 2c (re-present the plan; do NOT assume it was approved).
- Plan is `Status: approved` or later → this skill is done, and the file is read-only to you (see 2b). Hand off to `hars-execute`. If the user wants changes, follow the table in 2b rather than editing in place.
