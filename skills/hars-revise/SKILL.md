---
name: hars-revise
description: Harness-Driven Development, safe revision of already-approved documents. Changes a BDD spec or PLAN file that is no longer draft — rolling it back for re-approval when nothing has run yet, amending a not-yet-started task in place with an audit trail, forking to a new NNN when work is already done, or unstalling a blocked task. Use when the user wants to change, fix, re-scope, extend, or unblock a plan or spec that hars-plan already approved — "改 PLAN-003", "這個 task 的介面錯了", "spec 要加一個 scenario", "hars 卡住了要怎麼繼續", "unstall", "plan 要調整". Do NOT use it to write a new plan or spec (that is hars-plan), and do NOT use it on a plan still marked draft — hars-plan owns those outright.
---

# Hars — Revise (Changing What Was Already Approved)

An approved plan is a contract between a human who said "go" and an execution loop that will
never ask again. Changing it is therefore not editing — it is deciding **which kind of change
this is**, and paying that kind's price. This skill exists so that decision gets made once,
deliberately, instead of being improvised as a quick edit that quietly desynchronises the spec,
the plan, and the work already on disk.

## Trigger

User wants to change something already approved: "改 PLAN-003", "這個 task 的介面錯了",
"spec 少了一個 scenario", "hars 卡住了怎麼辦", "unstall", "把這個 task 重做".

- Plan still says `Status: draft` → **not this skill.** `hars-plan` owns draft plans; just edit and re-present at Gate 2.
- User wants a brand-new feature spec'd → `hars-plan`.
- User wants to know the current state before deciding → `hars-status` first, then come back.

## ⛔ Two rules that hold in every route

1. **This skill never writes `Status: approved`.** That stamp is the human consent gate and it
   belongs to `hars-plan` alone ([../hars-plan/plan-format.md](../hars-plan/plan-format.md) §4).
   Routes here either leave the plan `approved` untouched (amend), hand it back to `hars-plan`
   at `draft` (rollback), or create a new document that must earn its own approval (fork).
2. **Never edit a plan while an execution loop may be running.** Ask, and get an explicit answer.
   `hars-execute` writes task statuses and the Iteration Log as it goes; two writers means the
   record of what happened is lost, and that record exists nowhere else.

## Step 1 — Read before deciding

```bash
cat <working_dir>/plan/PLAN-NNN-<slug>.md
cat <working_dir>/bdd/BDD-NNN-<slug>.feature
```

Establish three facts, from the file:

- **Is a loop live?** Any task `in-progress` means either a run is active or one died mid-task. Ask the user which. If active → STOP until it is halted or the current task finishes.
- **How much work exists?** Count tasks that are `done`. This is what decides between rollback and fork, and it is not negotiable by preference — done work is evidence that cannot be re-derived from the file.
- **What is actually changing?** A behavior change (the spec is wrong / incomplete) is a different animal from an implementation-detail change (a task's interface, directory, or context is wrong). Behavior changes reach back to Gate 1.

## Step 2 — Route

| Situation | Route | Why this one |
|---|---|---|
| Nothing executed yet — plan `approved`, **every** task `pending` | **Rollback** | No progress exists to destroy, so the cheapest correct move is to re-open the whole document and re-approve it properly. |
| A **pending** task's scope, interface, directory, or context is wrong — and the spec's behavior is unchanged | **Amend** | Narrow, auditable, and re-running the Planner over completed work would rewrite history to fix a one-line mistake. |
| A task is `stalled` and you now know why | **Unstall** | The blockage is understood; the plan needs the fix plus permission to continue. |
| Any task is `done`, **or** the BDD's behavior itself changes, **or** the change is broad | **Fork** | The Coverage Check, the task decomposition, and the finished work would all have to be re-derived. That is a new plan, and pretending otherwise loses the old one's evidence. |
| A task is `in-progress` with a live loop | **STOP** | Wait for it to finish or be halted. Nothing here is urgent enough to race another writer. |

When two routes look plausible, take the more conservative one — Fork over Amend, Amend over
silent edit. The expensive failure is not an extra plan file; it is an approved document that no
longer describes what is being built.

---

## Route A — Rollback (nothing has run)

1. Confirm with the user that no execution loop is running or queued.
2. Set the plan header `Status: approved` → `draft`, and remove the `Approved:` line.
3. If the **spec** is what's changing, also set the BDD header back to `# Status: draft`.
4. Hand off to `hars-plan`, which resumes at Gate 1 (if the BDD reopened) or Gate 2, revises, and re-stamps.

Do not make the substantive edits here and hand over a finished document — `hars-plan` owns
draft content, and its gates are written to present work it produced. Reopen, then hand off.

## Route B — Amend in place (pending task, spec unchanged)

The plan stays `approved` the whole time. Nothing here manufactures consent, because the
amendment gets its own explicit confirmation and its blast radius is bounded to work that has
not started.

**Hard limits — all four, no exceptions:**
- Only tasks whose `Status:` is `pending`. Never a `done` task, never an `in-progress` one.
- Never the BDD spec. A behavior change is a Gate 1 matter → Fork (or Rollback if nothing ran).
- Never `## Coverage Check` rows belonging to `done` tasks, and the row count must still equal the scenario count when you finish.
- Never the header gates (`Pass threshold`, `Max iterations`) — those were approved as the run's strictness; changing them mid-run re-grades finished work against a standard it never faced. Changing them is a Fork.

**Steps:**

1. Write the exact before/after for each field you propose to change.
2. ⛔ **GATE — present it and wait.** This is a hard STOP; end your turn.

   ```
   [hars] PLAN-NNN amendment proposed (plan stays approved; only pending tasks touched).

   Task 3 "token bucket"
     Provides:  - Take(n int) bool
                + Take(ctx context.Context, n int) (bool, error)
     Why: Task 5 needs cancellation; the current signature can't carry it.

   Affects: task 3 (pending), task 5 (pending, depends on it). No done work touched.

   Reply "go" to apply, or tell me what to change.
   ```
3. On approval, apply the edits **and** append to an `## Amendments` section (create it if absent — append-only, newest last):

   ```markdown
   ## Amendments
   ### 2026-08-17 — Task 3 Provides
   Was: Take(n int) bool
   Now: Take(ctx context.Context, n int) (bool, error)
   Why: task 5 needs cancellation. Approved by user; tasks 3 and 5 both pending at the time.
   ```

   This section is the audit trail that replaces immutability. Without it, a plan that reads
   `approved` is indistinguishable from one a human actually read, which is the exact property
   the whole approval stamp exists to provide.
4. Check the ripple: any **pending** task whose `Depends on` includes the amended task may now
   be planned against a signature that changed. Amend those in the same pass, or say plainly
   that they need it and let the user decide — never leave a dangling contract.

## Route C — Unstall

A `stalled` task means `Max iterations` of Evaluator rejections. The blockage is a
misunderstanding, not bad luck, so:

> ⛔ **Never just clear the flag and re-run.** Nothing has changed, so the next loop stalls in
> the same place, having burned another full set of iterations to rediscover it.

1. Read the task's Iteration Log entries and the last Evaluator findings in full. Name what
   kept failing — a scenario the tests can't satisfy, an interface that doesn't fit, a missing
   constraint the plan never carried.
2. Decide what actually changes, and say it out loud:
   - **Missing context** (a gotcha nobody wrote down) → add it to `## Known Context` and follow Route B's gate and audit trail.
   - **Wrong scope or interface** → Route B on that task.
   - **The scenario itself is wrong or untestable as written** → the spec is at fault → Route D (fork). Do not weaken a scenario in place to make a task pass; that converts a real failure into a green run that proves nothing.
   - **Nothing to change — it needs a human** → say so and stop. Hand-implementing the task and marking it `done` is a legitimate outcome, but it must be the user's explicit call, and it belongs in the Iteration Log.
3. Only after a real change is applied: set the task `stalled` → `pending`, and the plan header
   `stalled` → `in-progress`. Record in the Iteration Log what changed and why the retry is
   expected to go differently. Then hand off to `hars-execute`.

## Route D — Fork to a new NNN

Used when work is already `done`, the behavior itself changes, or the change is too broad to
amend. The old documents stay exactly as they are — their finished tasks keep their evidence.

1. Determine the next NNN the same way `hars-plan` does (highest existing + 1).
2. Hand off to `hars-plan` to write the new BDD + plan pair through both gates. Give it, as
   input to its Phase 0 **Known Context**, the things a fresh planning session cannot see:
   - which tasks of PLAN-NNN are `done` and therefore **out of scope**;
   - the `Provides (public interface)` those finished tasks actually expose — the new plan builds against these real signatures, not against a fresh design;
   - why the old plan is being superseded, and any gotchas from its Iteration Log.
3. Close the old plan once the new pair is approved: set its header `Status: superseded` and add
   `Superseded by: PLAN-MMM`. `hars-execute` and `hars-status` both treat `superseded` as
   terminal, so it stops appearing as runnable work without pretending it finished.

   A partially-done plan left `in-progress` gets picked up by the next `hars run` — closing it
   is what keeps the fork from spawning two loops building overlapping things.

## Output

```
[hars] PLAN-NNN revise  route=rollback|amend|unstall|fork
  Changed: <fields / files touched, or "none — handed to hars-plan">
  Plan status: <before> → <after>
  Next: <hars-plan Gate 2 | hars run | nothing>
```
