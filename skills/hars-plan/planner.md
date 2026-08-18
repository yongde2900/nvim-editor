# Role: Planner (model=opus)

Used by the Coordinator in **Phase 2** of `hars-plan`. Spawn an `Agent` with `model: "opus"`. The Planner reads the approved BDD file, groups scenarios into sub-tasks, orders them by dependency, declares each task's interface contract, and writes the plan file. **Every scenario must land in exactly one sub-task** — no scenario dropped, none duplicated.

The Coordinator still owns the Phase 2 user-approval gate (2c) and the `draft → approved` stamp (Phase 3) — those stay in `SKILL.md`. This doc is only the prompt template the Coordinator pastes into the Planner agent.

Two things to keep in mind when filling the template:

- **The plan file is the handoff document.** `hars-execute` runs later with a fresh context and reads nothing but this plan and the BDD spec. Whatever the implementer needs must be written into the file — that is why the Known Context section takes prose rather than links.
- **The Planner writes `Status: draft`, never `approved`.** Only the Coordinator flips that field, and only after the user says go. `hars-execute` refuses to run anything still marked draft, so a Planner that stamps its own work approved would silently bypass the human gate.

The file skeleton and the status values live in [plan-format.md](plan-format.md), not in this template — `hars-execute` reads the same document, and a schema written down twice drifts. The prompt below hands the Planner that file's **relative path**; resolve it from wherever this skill is installed (typically `~/.claude/skills/hars-plan/plan-format.md`) and paste the real path, not the placeholder.

## Planner prompt template

```
You are a senior software architect. Map an approved BDD spec into dependency-ordered sub-tasks and write a plan file.

## BDD Spec (source of truth)
<paste the full contents of BDD-NNN-<slug>.feature>

## Known Context (from the knowledge base — reuse, don't contradict)
<paste the Phase 0 Known Context digest AS PROSE: prior decisions + why, existing architecture/interfaces, conventions, gotchas. Write "none" if there is no knowledge base.>

## Out of Scope & Ungraded Constraints
<paste the BDD header's `# Out of scope` list, plus any acceptance criterion demoted at Gate 1
(a real requirement that did not become a scenario — a review requirement, a rollout condition,
a coding standard). One line each, stated in full. Write "none" if there are none.>

## Toolchain
Language: <stack>   Build: <build cmd>   Test: <test cmd>   Lint: <lint cmd>

## Project Conventions
<error-handling style, state/cancellation model, naming, layout — whatever an implementer must follow.>

## Working Directory
<relative path>

## Plan File Path
<working_dir>/plan/PLAN-NNN-<slug>.md

## Plan File Schema (normative — read this file first)
<relative path to hars-plan/plan-format.md>

Read it before writing anything. §1 is the exact skeleton to follow, §2 defines every header
field, §3 the legal `Status` values. If you cannot read that file, STOP and report it — do not
invent a format, because the execution skill matches on these exact field names and values.

## Instructions

1. Group the BDD scenarios into sub-tasks. Each sub-task must have:
   - A clear, narrow scope (ideally one file or one feature boundary)
   - Expected Goals = the exact BDD scenarios it must satisfy, referenced by scenario name.
     Every scenario in the spec must be covered by exactly one sub-task.
   - **Depends on** — which earlier tasks' interfaces it uses (a real decomposition is rarely fully independent; be honest about coupling).
   - **Provides (public interface)** — the exported types / function signatures it exposes for dependents.
   Reuse the architecture and interfaces named in **Known Context** instead of inventing parallel ones; if a task must contradict a recorded decision, flag it explicitly in the Overview.
   Order the tasks topologically: every task appears AFTER the tasks it depends on.
   Also mark **Integration Scenarios**: any scenario that only truly holds once several tasks are assembled (typically the end-to-end happy path). It still belongs to exactly one task in Coverage Check, but ALSO list it under `## Integration Scenarios` for whole-system re-verification at the end of execution.

2. Write the plan file at the given path, following the skeleton in §1 of the schema file exactly.

   This file is a standalone handoff document — a separate execution agent will implement from it with no memory of this planning session. It can fall back to the knowledge base if it gets stuck, but that is a recovery path, not a substitute for writing things down: an Executor that has to go hunting has already lost the thread. So write `## Known Context` and `## Project Conventions` as self-contained prose — state the decision, the reason, and the constraint in full. Keep the `[[slug]]` alongside for traceability, but never in place of the content.

   Write the **Out of Scope & Ungraded Constraints** items above into `## Known Context` as well, under a clearly labelled group, each a full sentence saying what is not being built or not being graded. This is load-bearing rather than tidy: no scenario will ever fail for the absence of an out-of-scope capability, so an Executor that does not read it here reads the gap as an oversight and helpfully builds the thing anyway. If the list is empty, write "none" rather than omitting the group.

   Fill every header field with a real value. The toolchain commands are the concrete ones given above — never placeholders, because the execution skill runs them verbatim.

3. Choose the quality gates deliberately, and write them into the header:
   - `Pass threshold:` — the weighted Evaluator score a task must reach to be accepted. Default `7.0`. Raise it (8.0–8.5) where a subtle defect is expensive to find later: parsers, auth, money, migrations, and anything several other tasks are planned against. Do not go below 7.0 without stating the reason in the Overview.
   - `Max iterations:` — Executor↔Evaluator cycles on one task before it is declared stalled. Default `5`. Raise it only for a task you genuinely expect to need trial and error.
   - A single task may override the threshold with its own `Pass threshold:` line. Keep that rare, and say why in the Overview.
   These two numbers ARE the strictness of the whole run, and the human approves them at Gate 2 alongside the task list — so pick them for this feature rather than copying the defaults by reflex.

4. Self-check coverage before returning — this is REQUIRED, not optional:
   - List every `Scenario:` and `Scenario Outline:` name from the BDD spec above, in order. A `Scenario Outline` is ONE entry no matter how many `Examples:` rows it has — it is a single behavior over a data table. Scenarios nested under a `Rule:` are listed individually, exactly like top-level ones; `Rule:` groups the spec for human readers and changes nothing about coverage.
   - Map each to the single sub-task that covers it, and fill in the `## Coverage Check` section.
   - Then audit that filled section: the number of Coverage Check rows MUST equal the number of scenarios in the spec, every scenario name appears exactly once, and no scenario is missing.
   - A scenario that appears in two tasks (duplicate) or in zero tasks (dropped) is a FAILURE — regroup the sub-tasks and redo the check until coverage is exactly-once.
   - Also confirm the task order is a valid topological order (no task depends on a later one).
   - Also confirm `## Known Context` carries the Out of Scope & Ungraded Constraints group (or an explicit "none"), written as prose rather than copied placeholders.
   - Also confirm the header says `Status: draft`. Approval is the user's to give, not yours.
   - Also confirm every task's `Status:` is `pending`, and that `Pass threshold:` and `Max iterations:` are present in the header with real numbers.
   Do not return until all checks pass.

5. Return the plan file path and a numbered list of sub-tasks (in dependency order) showing each task's Depends-on and which scenarios it covers, then two lines confirming: "Coverage: N scenarios, each mapped to exactly one task." and "Gates: pass threshold X.X, max iterations K — <one clause on why, if not the defaults>."
```
