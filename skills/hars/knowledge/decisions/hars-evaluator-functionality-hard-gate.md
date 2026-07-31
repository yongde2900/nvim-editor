---
title: hars Evaluator makes functionality a 50% hard gate grounded in test results
type: decisions
date: 2026-07-30
tags: [hars, evaluator, grading, testing]
---

The hars Evaluator's rubric was rebalanced to: **functionality 50% (hard gate), craft 25%,
clarity 15%, fit 10%** — and the old `originality (30%)` criterion was removed. A task
`PASSED` only if EVERY scenario is met AND the weighted score ≥ 7.0.

**What was decided + why:**
- **Functionality dominates and gates.** The old rubric weighted functionality only 20% while
  quality+originality were 60%. That could reject correct-but-plain code on subjective style,
  and "originality" actively penalized boilerplate — which is often exactly what you want.
- **Functionality is grounded in the executed test results**, not in reading the source. The
  Evaluator is given the raw Phase-3 test output and must judge whether the tests *genuinely
  exercise* each scenario's Given/When/Then; a scenario with no real assertion is `unmet`
  even when the suite is green. The Evaluator also reads files from disk itself (not pasted),
  which keeps the Coordinator's context small.
- Explicit instruction: do NOT reject correct, all-scenarios-met code for being "plain."

**Evidence (control/treatment subagent test):**
- NEW rubric on *fake-green* code (tests pass, assert nothing): 3/3 correctly `PASSED: false`,
  scenarios `unmet` — the hard gate is not a rubber stamp.
- NEW rubric on genuinely-complete plain code: 3/3 `PASSED: true` (9.3–9.7) — not over-strict,
  not penalized for being idiomatic.
- The sharp, real difference surfaced: on code whose *source* is correct but whose *test*
  doesn't check a scenario, the OLD rubric passed it ("verified by inspection of the source")
  while the NEW rubric marks it `unmet`. That is the intended behavior — stop rubber-stamping
  functionality by reading source.
- Caveat: the hypothesized baseline "old rubric rejects correct plain code" did NOT reproduce
  in isolation (old passed it 7.5–8.7). See [[isolated-tests-may-not-reproduce-full-flow-failures]].

Related: [[hars-bdd-single-source-of-truth]], [[validating-skill-changes-with-subagents]].
