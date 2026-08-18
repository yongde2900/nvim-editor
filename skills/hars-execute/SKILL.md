---
name: hars-execute
description: Harness-Driven Development, execution half. Picks up an approved PLAN-NNN.md development document and runs it to completion — selecting the next unblocked sub-task, spawning an Executor to implement it TDD-style, spawning a fresh-context Evaluator to grade it against the BDD scenarios, iterating until it passes, then handing off to the integration gate. Use this whenever the user says "hars run", "hars continue", "hars execute", "harness 執行", "跑下一個 task", or asks to resume or continue a harness plan. Safe to call repeatedly — it is idempotent and reports cleanly when there is nothing to do. Do NOT use it to write specs or plans (hars-plan), to merely report progress or answer whether a plan is pending (hars-status), to change an approved plan (hars-revise), or to run the whole-system integration gate on its own (hars-verify).
---

# Hars — Execute (Implementation Loop Half)

Consumes the **development documents** produced by `hars-plan` and drives them to done. This skill is designed to be invoked over and over: every run re-derives its position from the plan file on disk, does the next unit of work, writes the result back, and stops. No conversational state carries between runs.

**Role split:**
- **You = Coordinator** — locate and validate the plan, pick the next runnable task, orchestrate agents, verify from disk, manage plan state, report. This file is your playbook.
- **Executor (model=sonnet)** — implement one sub-task: Red → Green → Refactor → Regulate. Prompt template: [executor.md](executor.md)
- **Evaluator (model=sonnet)** — fresh context, reads the code from disk, reviews quality, confirms the executed tests genuinely cover each BDD scenario. Prompt template: [evaluator.md](evaluator.md)

📐 **The plan file's schema and its `Status` values are defined in [../hars-plan/plan-format.md](../hars-plan/plan-format.md)** (installed alongside this skill, typically `~/.claude/skills/hars-plan/plan-format.md`). §3 is the state machine you drive and §4 says which fields are yours to write. Read it if anything about the file surprises you — but never widen it: the selection logic below matches those exact strings, and a status nobody defined matches no branch and strands the plan.

## Trigger

User says: "hars run", "hars continue", "hars execute", "harness 執行", "跑下一個 task", "resume the plan", or asks what plans are pending.

If there is no approved plan yet — or the user is describing a feature rather than asking to build a planned one — that is `hars-plan`. Do not write specs here.

## Workflow

```
Invocation
  → Phase E0  Locate the plan → validate it is approved → pick the next runnable task
       • nothing runnable      → report and stop (this is a normal outcome, not an error)
       • a task is stalled     → report the blocker and stop
       • all tasks done        → jump to Phase 6
  → Phase 3   Spawn Executor (Red→Green→Refactor→Regulate) → re-run Lint + Test from disk
  → Phase 4   Spawn Evaluator (fresh context, grades against this task's BDD scenarios)
  → Phase 5   PASS → mark done, loop back to Phase E0 for the next task
              FAIL → re-spawn Executor with findings, increment iteration
  → Phase 6   All tasks done → hand off to hars-verify (whole-project build, Integration
              Scenarios driven end-to-end, plan stamped done, knowledge persisted)
```

**No approval gates live here.** Both gates were held by `hars-plan`; the `Status: approved` stamp on the plan file is what carries that consent forward. This is exactly why Phase E0 refuses to touch a plan that isn't stamped — without that check, an unattended loop could implement something no human ever signed off on.

---

## Phase E0 — Locate, Validate, Select

Do this on **every** invocation, including mid-loop continuations. It is cheap and it is what makes the skill safe to re-run.

### E0a — Locate the plan

```bash
ls <working_dir>/plan/PLAN-*.md 2>/dev/null
```

- **User named a plan** (a path, or an NNN like "run 003") → use that one.
- **No plan files at all** → report: nothing to execute, suggest `hars-plan`. Stop.
- **Exactly one candidate** → use it.
- **Several candidates** → prefer `Status: in-progress` over `Status: approved` (finish what's started before opening a new front). Among equals, take the lowest NNN. If two or more are genuinely tied and you cannot tell which the user means, list them and ask — don't guess.

Read the plan file and the BDD spec it names in its header. Those two documents are your primary context — you do not need to survey `./knowledge/` to get started, because everything the Planner anticipated was copied into the plan's `## Known Context` and `## Project Conventions`. (The knowledge base stays available as a fallback when something goes wrong mid-task; see Phase 3.) If those sections are empty or contain only bare `[[slug]]` links, say so in your report: the plan is under-specified and the user should re-run `hars-plan` rather than have you invent the missing constraints.

### E0b — Validate approval (hard gate)

Check the plan header `Status:` field.

| Status | Action |
|--------|--------|
| `approved` | Proceed. Flip it to `in-progress` when you start the first task. |
| `in-progress` | Proceed — this is a resumed run. |
| `draft` | ⛔ **STOP.** The plan was never approved by a human. Report: "PLAN-NNN is still draft — it needs approval via hars-plan before I can execute it." Do NOT run it, do NOT ask for approval yourself, do NOT infer approval from the user having said "hars run". |
| `done` | Nothing to do. Report and stop. |
| `superseded` | Nothing to do — this plan was forked away from. Report it, naming the `Superseded by:` plan, and stop. |
| `stalled` | ⛔ **STOP.** Report the stalled task and its Iteration Log, and route the user to `hars-revise`. Do NOT clear the flag and retry: nothing has changed, so it will stall in the same place. |

Also confirm the BDD file header reads `# Status: approved`. If it doesn't, the plan is built on an unapproved spec — stop and report.

Then read the two gate fields from the header and use them for the rest of the run — **you have no defaults of your own**, because how strictly this plan is graded is part of what the human approved:

- `Pass threshold:` — the score a task must reach to be accepted (Phase 4/5).
- `Max iterations:` — cycles on one task before it goes `stalled` (Phase 5).

If either field is absent (an older plan written before they existed), fall back to `7.0` / `5` and say so explicitly in your run report — silently picking numbers is how a plan ends up graded to a standard nobody agreed to.

The draft check is the single most important line in this skill. A plan is a plausible-looking document whether or not anyone read it; the stamp is the only evidence that someone did.

### E0c — Select the next runnable task

Derive it from the file — never from memory of a previous run:

The only legal task statuses are `pending`, `in-progress`, `done`, `stalled` (see [../hars-plan/plan-format.md](../hars-plan/plan-format.md) §3). Check that first — anything else is a corrupt plan, not a task to interpret:

```
if any task has a Status outside {pending, in-progress, done, stalled}
                                    → STOP, report status=BLOCKED naming the task and the bad
                                      value. Do NOT guess what it meant, and do NOT rewrite it
                                      to something legal — a status nobody defined means an
                                      earlier run or a hand edit left the plan inconsistent.

if any task has Status: stalled     → STOP, report blocker, ask the user
if all tasks have Status: done      → go to Phase 6
if a task has Status: in-progress   → resume that one (a prior run was interrupted mid-task)

candidates = tasks where Status == pending
             AND every task in its "Depends on" has Status == done
next = the lowest-numbered candidate

if candidates is empty (and not every task is done)
    → the dependency graph is unsatisfiable. STOP and report status=BLOCKED;
      do NOT skip ahead to a later task — that breaks the topological order the
      Provides/Depends contracts rely on.
```

Note there is no `failed` task status. A task that flunks an Evaluate cycle stays `in-progress` — its failure lives in the Iteration Log — and only becomes `stalled` on exhausting `Max iterations`. If you find a `failed` in a plan, it came from an older version of this skill: treat it as the corrupt-status case above and report it.

Announce the selection, then proceed to Phase 3:

```
[hars] PLAN-NNN  selected task=N/M  "<task name>"  (depends on: <...>)
```

---

## Phase 3 — Execute (spawn Executor, model=sonnet)

1. Mark this task `Status: in-progress` in the plan file **before** spawning. If the run dies mid-task, that mark is how the next invocation knows where it was.
2. Spawn an `Agent` with `model: "sonnet"` using the Executor prompt template.

📄 **Executor prompt template → [executor.md](executor.md).** Open it, fill the `<...>` placeholders (this task's scenarios from the BDD file, the dependencies' `Provides` interfaces from the plan, working dir, toolchain, and the plan's `## Project Conventions` / `## Known Context`), and paste it as the Executor agent's prompt.

3. After the Executor returns, **verify from disk yourself** — run the plan header's **Lint cmd** and **Test cmd** scoped to this task's directory. The Executor's self-report is not evidence; the terminal is.
4. Keep the raw test output verbatim — the Evaluator needs it.
5. If lint or tests fail, re-spawn the Executor with the failure output as additional context and increment the iteration count.

### Knowledge base as a fallback

The plan carries what the Planner anticipated. When reality diverges from that — a failure nobody predicted, a convention the plan doesn't cover — the knowledge base is the cheap next place to look, ahead of searching the codebase: it records decisions *with their reasoning* and gotchas that leave no trace in code.

The Executor does this itself when stuck (see its template). Do the same at your own level when diagnosing a repeated failure or an integration break in Phase 6: `cat ./knowledge/index.md`, open the entries touching the failing area, and feed what you find into the next Executor's "Previous Attempt" section.

What the knowledge base cannot do is override the plan. If an entry contradicts the approved plan's conventions or interface contracts, the plan wins — report the conflict rather than quietly executing something the user didn't approve.

---

## Phase 4 — Evaluate (spawn Evaluator, model=sonnet)

> ⛔ **MANDATORY CHECKPOINT — no skipping, no batching multiple tasks together**
>
> Before spawning the Evaluator, confirm ALL of the following:
> 1. The project's **Build cmd** passes — OR the task is a non-code artifact.
>    **Both cases still require Evaluate.**
> 2. Tests pass — OR the task has no tests because it is a non-code artifact.
>    **No tests does NOT mean skip Evaluate.**
> 3. Evaluating **this task only** — do NOT bundle goals from other tasks.
> 4. MUST wait for the Evaluator result and confirm `PASSED: true` before starting the next task.
>
> ❌ Violations:
> - Combining multiple tasks into one Evaluator prompt
> - Skipping Evaluate and moving directly to the next task
> - Self-judging that a task "should pass" and omitting the Evaluator
>
> A violation means the results are untrusted — re-evaluate from the violated task.

The temptation to skip grows the longer the loop runs, and it is strongest exactly where it is most dangerous: on the tasks that look boring. The Evaluator exists because green tests and met scenarios are different claims — a suite can pass while quietly testing nothing.

📄 **Evaluator prompt template → [evaluator.md](evaluator.md).** Open it, fill the `<...>` placeholders (this task's scenarios as the grading standard, the raw Test cmd output from Phase 3, and the **pass threshold** for this task), and paste it as the Evaluator agent's prompt.

---

## Phase 5 — Iterate or Advance

After receiving the Evaluator's verdict, update the plan file:

```markdown
### Task N: <name>
Status: done           ← on a pass; on a failed cycle it STAYS in-progress
Expected Goals (from BDD scenarios):
- [x] Scenario: <name>
- [x] Scenario: <name>

## Iteration Log
### Task N — Iter M — score X.X/10 — PASS|FAIL
- Changed: ...
- Remaining: ...
```

| Condition | Action |
|-----------|--------|
| `PASSED: true` + tests pass | Mark task `done`. Return to **Phase E0c** to select the next task. |
| `SCORE` below the plan's **Pass threshold**, or any scenario `unmet` | Leave the task `in-progress`, log the cycle, and re-spawn the Executor with the Evaluator's findings. Increment iter count. |
| All tasks `done` | Proceed to **Phase 6** before declaring the plan done. |
| Iterations on one task reach the plan's **Max iterations** with no pass | Mark the task `Status: stalled` **and the plan header `Status: stalled`**. Report the blocker. Ask the user how to proceed — do NOT move on to other tasks. |

Use the threshold and iteration cap you read from the plan header in E0b (defaults `7.0` / `5` only if the plan predates those fields). A task-level `Pass threshold:` line, if present, overrides the header for that task alone.

**A failed cycle does not change the task's status.** It stays `in-progress` and the failure is recorded in the Iteration Log — that is what tells the next invocation to resume here rather than treating the task as finished or unstarted. Never write `failed`; it is not a legal value and would match no branch in E0c.

**Stalling is a two-line write.** Marking only the task leaves the plan header saying `in-progress`, so the next invocation walks the whole selection tree again just to rediscover the same blockage — and an outer loop polling this skill sees a plan that still looks runnable. Setting the header too makes E0b stop the run immediately, which is the point.

Write the plan file after every cycle, not just at the end. The file is the only thing that survives this invocation.

Once you start executing, **you own the plan file's mutable fields** — the plan header `Status:`, task `Status:`, the Expected Goals checkboxes, and the Iteration Log ([../hars-plan/plan-format.md](../hars-plan/plan-format.md) §4 has the full table). `hars-plan` treats any non-draft plan as read-only for exactly this reason. Do not rewrite the parts that aren't yours: the header toolchain, `## Known Context`, `## Project Conventions`, task scopes, `Depends on`, `Provides`, and `## Coverage Check` are the approved plan, and editing them here would mean executing something different from what the user signed off on. If one of them is wrong, that is a BLOCKED report, not a fix.

Output after each Evaluate cycle:

```
[hars] PLAN-NNN  task=N/M  iter=K  score=X.X/10  status=PASS|FAIL  — <one sentence>
```

### Continuing to the next task

Loop Phase E0c → 3 → 4 → 5 for as long as tasks remain runnable.

This skill is often driven by an outer loop — an unattended agent that invokes it repeatedly until it says to stop. That only stays safe if the stop conditions are honoured exactly, because the outer loop has no judgement of its own: whatever you report, it acts on.

**Terminate and hand control back to the user when ANY of these hold:**

| Termination condition | Report as | Why it must stop |
|-----------------------|-----------|------------------|
| A task hit the plan's **Max iterations** → `stalled` | `status=STALLED` | That many Evaluator rejections means the task is misunderstood, not unlucky. One more attempt burns tokens on the same wrong idea. |
| No runnable candidate but pending tasks remain | `status=BLOCKED` | The dependency graph is unsatisfiable. Skipping ahead breaks the Provides/Depends contracts later tasks were planned against. |
| Plan header is `draft` / BDD not approved | `status=NOT_APPROVED` | Nobody signed off. Consent cannot come from the invocation itself. |
| Plan's Known Context / Conventions are empty or slug-only | `status=UNDERSPECIFIED` | The missing constraints have to be supplied by `hars-plan`, not guessed here. |
| All tasks done, `hars-verify` returned `DONE` | `status=DONE` | Finished — and verified as a whole, not just task by task. |
| Nothing to run at all | `status=IDLE` | Normal outcome — see below. |
| The user asked for a single task | `status=PAUSED` | Respect the scope they asked for. |

⛔ **On STALLED and BLOCKED specifically:** report and stop. Do NOT retry a sixth time, do NOT jump to a later task to keep the loop productive, and do NOT reopen a `done` task looking for something to fix. An idle loop is a correct loop; a loop that invents work to avoid reporting a blocker destroys the evidence of what went wrong.

Every termination reason belongs in the report with enough detail to act on — for a stall, include the failing scenarios and the last Evaluator findings, since that is what the user needs to decide between revising the plan, revising the spec, or implementing by hand.

---

## Phase 6 — Hand Off to the Integration Gate (MANDATORY before done)

Per-task Evaluators only judged tasks in isolation. Cross-cutting behavior stays unverified until the pieces are assembled — so every task passing is not the same claim as the plan working.

> ⛔ Do NOT set the plan `Status: done` yourself, from per-task passes or from anything else. You do not own that field.

When every task is `done`, **invoke the `hars-verify` skill** for this plan. It builds the whole project, runs the full suite, drives every Integration Scenario end-to-end against the assembled system, and — only if all of that is green — stamps the plan `done` and persists what the run taught to the knowledge base.

It comes back with one of:

| hars-verify result | What you do |
|---|---|
| `status=DONE` | Report `status=DONE` and stop. The plan is finished and the knowledge is saved. |
| `status=REOPENED` | It set a task back to `in-progress` because an integration failure traced to that task's scope. Return to **Phase E0c**, which will select it, and run it through Phase 3–5 with the integration failure as the Executor's "Previous Attempt" context. Then the gate runs again. |
| `status=FAIL` with no task at fault | Report and stop. A failure in code this plan never touched is not a task to reopen — reopening an innocent task burns a full Executor cycle and pollutes its history. |

Keeping the gate in a separate skill is what lets it also be run on demand — after a refactor, a dependency bump, or a merge — without dragging the execution loop along. The rule that a plan cannot reach `done` any other way is unaffected by where the gate lives.

---

## Nothing To Do Is a Normal Outcome

This skill is meant to be polled. If a run finds no approved plan, no runnable task, or an already-finished plan, that is a clean result — report it plainly and stop.

(If the user only wanted to *know* whether anything is pending, `hars-status` answers that without loading this loop or touching a file. Being asked a question is not a reason to run one.)

```
[hars] No approved plan with pending work.
  PLAN-002 — done
  PLAN-003 — draft (needs approval via hars-plan)
```

Do not invent work, do not re-run finished tasks to look busy, and do not promote a draft plan just because nothing else is available. Re-running with nothing pending should be harmless and quiet.

Because an outer loop may be polling this skill on a timer, an IDLE report is the signal that it can back off or exit — so it has to be accurate. Reporting activity that didn't happen keeps the loop spinning; reporting IDLE when a task was actually runnable silently abandons the plan.

---

## Resume After Interruption

No special path needed — Phase E0 *is* the resume logic. Just invoke the skill again; it will re-read the plan, find the `in-progress` task or the next runnable one, and carry on from the Iteration Log.

```bash
cat <working_dir>/plan/PLAN-NNN-<slug>.md      # status, progress, iteration log
cat <working_dir>/bdd/BDD-NNN-<slug>.feature   # the approved scenarios
```
