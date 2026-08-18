---
name: hars-status
description: Harness-Driven Development, read-only status reporter. Answers questions about hars plans without touching anything — which PLAN files exist, what state each is in, how many sub-tasks and BDD scenarios are done, what the last Evaluator score was, which task is blocked, and what the next action would be. Use whenever the user asks "hars status", "hars 進度", "有沒有待辦的 plan", "PLAN-003 到哪了", "哪個 task 卡住了", or wants a progress summary before deciding whether to run anything. Also use as the cheap pre-check before hars-execute. It never spawns agents, never edits a plan, and never implements — to run a plan use hars-execute, to change one use hars-revise.
---

# Hars — Status (Read-Only Reporter)

Answers "where are we?" by reading files. Nothing else.

This exists because asking a question shouldn't load an execution playbook. `hars-execute` is a
loop that changes state; reaching for it to find out whether there *is* anything to run puts a
skill that writes plan files in the path of a question that only reads them.

## Trigger

User asks: "hars status", "hars 進度", "有沒有待辦的 plan", "PLAN-003 到哪了", "哪個 task 卡住", "跑到哪了", or anything else that is a **question about** plans rather than an instruction to act on them.

If they want to run the next task, that is `hars-execute`. If they want to change a plan, that is `hars-revise`. Report and hand off — do not start doing the thing you just described.

## ⛔ The read-only guarantee

This skill **never**:
- writes to a plan file, a BDD file, or the knowledge base — not even to fix something obviously broken;
- spawns an Executor, Evaluator, Planner, or any other agent;
- runs the project's Build / Test / Lint commands (that is `hars-verify`'s job, and it costs real time);
- implements, edits, or "tidies" anything it finds.

The guarantee is the feature. It makes this safe to call from a hook, a statusline, a polling
loop, or reflexively mid-conversation, and it means a status check can never be the thing that
corrupted an execution run. If you find a broken plan, **say so and stop** — §S3.

## Workflow

```
Invocation
  → S1  Locate every plan (+ the BDD spec each names)
  → S2  Read each one's header, task statuses, coverage, and last Iteration Log entries
  → S3  Check internal consistency — report problems, never repair them
  → S4  Render the summary, ending with the single next action
```

### S1 — Locate

```bash
ls <working_dir>/plan/PLAN-*.md 2>/dev/null
```

- No plan files → report that plainly and suggest `hars-plan`. This is a normal answer, not an error.
- The user named one (a path, or an NNN like "003") → report that one in detail (§S4 detail form).
- Otherwise → report all of them in summary form, newest NNN last.

### S2 — Read

For each plan, from the file only — never from memory of an earlier run in this conversation:

| From the plan header | From the body |
|---|---|
| `Status`, `Created`, `Approved` | every task's `Status` and name |
| `BDD Spec` path | `Expected Goals` checkboxes (scenarios done / total) |
| `Pass threshold`, `Max iterations` | `## Coverage Check` row count |
| Build / Test / Lint cmds (presence only — do not run them) | `## Integration Scenarios` count |
| | the last two or three `## Iteration Log` entries: task, iter, score, PASS/FAIL |

Also read the BDD file's `# Status:` header line. Counting its `Scenario:` lines is cheap and
is what makes the coverage check in S3 possible:

```bash
grep -c '^\s*Scenario:' <working_dir>/bdd/BDD-NNN-<slug>.feature
```

### S3 — Consistency check (report, never repair)

The plan file is a state machine driven by two different skills across sessions
([../hars-plan/plan-format.md](../hars-plan/plan-format.md) §3). Nothing else routinely reads
the whole file, so this is the one place inconsistencies get noticed. Flag every one you find;
**fix none of them** — a status check that silently rewrites state is worse than no check.

- [ ] Any task `Status` outside `pending | in-progress | done | stalled` — including a `failed` left by an older version of the skills.
- [ ] Plan header disagrees with the tasks: header `in-progress` but every task still `pending`; header `approved` but tasks already `done`; every task `done` but header not `done` (→ integration verification is outstanding, see S4); header `stalled` with no `stalled` task, or a `stalled` task under a header that isn't `stalled`.
- [ ] `Pass threshold` or `Max iterations` missing (an older plan — `hars-execute` will fall back to `7.0` / `5` and say so).
- [ ] `## Coverage Check` row count ≠ the BDD's `Scenario:` count, or a scenario named twice.
- [ ] Plan is `approved` or later but its BDD header is not `# Status: approved`.
- [ ] `## Known Context` or `## Project Conventions` empty, or only bare `[[slug]]` links — the plan is under-specified and `hars-execute` will refuse it.
- [ ] A task whose `Depends on` names a task that appears later in the file.

Report these under a `⚠` block with the fix routed to the right skill (almost always
`hars-revise`, or `hars-plan` if the plan is still draft).

### S4 — Report

Summary form, one line per plan:

```
[hars] 3 plans in <working_dir>

PLAN-001  user auth        done         5/5 tasks · 12/12 scenarios
PLAN-002  rate limiter     in-progress  2/4 tasks · 7/13 scenarios · task 3 "token bucket" iter 2/5, last score 6.5 FAIL
PLAN-003  csv export       draft        4 tasks · 9 scenarios — never approved

Next: "hars run" resumes PLAN-002 at task 3.
```

Detail form, when a single plan was asked about, adds: the per-task list with dependencies and
scenario counts, the Integration Scenarios, gates (`threshold 7.0, max 5 iters`), and the last
few Iteration Log entries verbatim — for a stalled task, quote the last Evaluator findings in
full, since that is exactly what the user needs to decide what to do next.

### The next-action line

End every report with exactly one next action. It is the whole point of being asked.

| Plan state | Next action |
|---|---|
| `draft` | `hars-plan` — it was never approved; re-present at Gate 2 |
| `approved` | `hars run` — starts at task 1 |
| `in-progress`, a task is runnable | `hars run` — resumes at task N |
| `in-progress`, every task `done` | `hars verify` — the integration gate hasn't run |
| `stalled` | `hars-revise` — quote the blocker; do not suggest just re-running |
| `done` | nothing pending (`hars verify` if they want to re-check it after a refactor) |
| `superseded` | nothing — name the plan that replaced it |
| several plans runnable | the one `hars-execute` would pick: `in-progress` before `approved`, then lowest NNN |

If a consistency problem from S3 blocks that action, say so instead of suggesting a command
that will immediately stop.
