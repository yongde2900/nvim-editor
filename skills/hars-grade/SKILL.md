---
name: hars-grade
description: Harness-Driven Development, standalone evaluator. Grades existing code against BDD scenarios using a fresh-context reviewer — runs the tests first for evidence, then scores functionality, craft, clarity, and fit, and marks each scenario met or unmet with the test that covers it. Use when the user wants code judged against a spec without running an implementation loop: "hars grade", "用 BDD 評這段 code", "這個 PR 有滿足 spec 嗎", reviewing an implementation someone else wrote, checking whether existing code already satisfies a feature file, or sanity-checking a task hars-execute marked done. It never edits a plan file and never implements — for the full implement-and-grade loop use hars-execute.
---

# Hars — Grade (Standalone Evaluation)

The Evaluator is the most reusable piece of hars: a fresh-context reviewer that grades code
against Given/When/Then and refuses to accept a green suite as proof the behavior exists. This
skill exposes it on its own, for code that no execution loop produced.

**Role split:**
- **You = Coordinator** — pin down the grading standard, run the tests for evidence, spawn the Evaluator, report the verdict.
- **Evaluator (model=sonnet)** — fresh context, reads the code from disk, grades against the scenarios. Prompt template: [../hars-execute/evaluator.md](../hars-execute/evaluator.md) — normative there, shared here so the two never drift.

## Trigger

User says: "hars grade", "用 BDD 評這段 code", "這段有符合 spec 嗎", "評一下這個 PR", or wants
existing code judged against scenarios without implementing anything.

If they want the code *written* to satisfy the scenarios, that is `hars-execute` (or `hars-plan`
first, if there is no plan). Grading is a verdict, not a step toward a fix.

## ⛔ Never touches plan state

Even when the code you are grading belongs to a plan, and even when the verdict is unambiguous:

- Never set a task `done`, `stalled`, or anything else; never tick an Expected Goals checkbox; never append to the Iteration Log.
- Never mark a plan `done` — that is `hars-verify`'s gate, and it requires the whole assembled system.

A `PASSED: true` from this skill is **information**, not a state transition. `hars-execute`'s
per-task gate means a specific thing: that task's Evaluator saw that task's scope with that
task's test output at that point in the loop. A grade produced here, possibly against different
code at a different time, is not that — and writing it into the plan would forge exactly the
evidence the harness exists to produce honestly.

## Workflow

```
Invocation
  → G1  Fix the grading standard (which scenarios?)
  → G2  Fix the target (which code?)
  → G3  Run the tests — evidence, not self-report
  → G4  Spawn the Evaluator (fresh context)
  → G5  Report the verdict, and say what it does and doesn't mean
```

### G1 — Fix the grading standard

A grade is only as meaningful as the standard behind it. In order of preference:

1. **An existing BDD file** — `<working_dir>/bdd/BDD-NNN-<slug>.feature`. Best case: it was already approved, so the standard is not one you invented for this grading.
2. **A specific plan task's scenarios** — the user points at PLAN-NNN task 3; take that task's `Expected Goals` scenarios from the BDD file, and its `Provides (public interface)` as the interface contract.
3. **Scenarios the user states now** — write them out as Gherkin and get a nod before grading. Apply `hars-plan`'s scenario quality bar: every scenario needs Given/When/Then and an **observable, checkable Then**. "Works correctly" is not a standard, and grading against it produces a number that means nothing.

If no standard can be pinned down, stop and say so. Ungrounded code review is a different
request, and there are better tools for it than a rubric with a hard gate.

### G2 — Fix the target

A directory, a set of files, or a diff/PR. Be explicit in the report about what was in scope —
"the auth package" and "the auth changes in this PR" produce different verdicts, and a scenario
can be `unmet` simply because its implementation sits outside the scope you were given.

### G3 — Run the tests yourself

Run the project's test command, scoped to the target. This output is the Evaluator's evidence
for the functionality criterion — the hard gate — and it must be real:

- **Never** paste the user's claim that tests pass, or a summary from a previous session, or a CI badge.
- If there are **no tests**, say so and pass that fact through. The Evaluator grades functionality on whether the scenarios are genuinely exercised — untested code fails that honestly, which is a useful answer, not an obstacle.
- If the tests **don't compile or error out**, that is the evidence. Pass it through verbatim rather than fixing it; fixing it makes you the author of what you're about to grade.

### G4 — Spawn the Evaluator

Spawn an `Agent` with `model: "sonnet"` using
[../hars-execute/evaluator.md](../hars-execute/evaluator.md). Fill its placeholders from what you
established above: the scenarios as the grading standard, the interface contract (or "none"),
the raw test output, and the target directory.

**Pass Threshold:** use the plan's if the code belongs to one; otherwise `7.0`, and say in the
report which you used. The threshold determines what `PASSED` means, so it is never implicit.

⛔ **Never paste your own reading of the code, the author's explanation, or a prior review into
that prompt.** The fresh context is the entire value: someone who has never seen the intent can
only judge what is actually on disk, which is exactly the check a green test suite cannot make.

### G5 — Report

```
[hars] grade  target=<dir/PR>  standard=<BDD-NNN | task N | ad-hoc scenarios>
  SCORE: X.X/10  (threshold X.X)   PASSED: true|false
  Scenarios: K met / M total
    [met]   <name> — covered by <test>
    [unmet] <name> — <why>
  Issues:
    [error]   <criterion>: <finding>
    [warning] <criterion>: <finding>
```

Then one line on what the verdict means here — and what it does not:

- Grading a plan's task → *"this is not a hars-execute gate result; the plan is unchanged."*
- Grading pre-existing code before planning → *"scenarios already met by existing code are worth telling `hars-plan` about in Phase 0, so they don't get re-planned as new work."*
- Grading a PR → the `unmet` scenarios and `error` issues are the review comments; the score on its own is not.

If the verdict is FAIL and the user wants it fixed, hand off — `hars-execute` if it belongs to an
approved plan, `hars-plan` if it needs a spec first, or a plain fix if it is a one-liner. Do not
start implementing inside this skill: the reviewer who fixes the code has stopped being able to
review it.
