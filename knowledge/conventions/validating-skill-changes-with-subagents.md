---
title: How skill changes here are validated (subagent control/treatment tests)
type: conventions
date: 2026-07-30
tags: [skills, testing, methodology, subagents]
---

Edits to the hars (and similar) skills follow the `superpowers:writing-skills` Iron Law:
**no skill change without a test.** The convention used in practice:

- **Fresh-context subagents as the unit of test.** Dispatch general-purpose subagents (sonnet
  — weaker adherence = stronger stress test; the real Coordinator is opus, so passing on
  sonnet is conservative) that read the skill and act out the relevant role.
- **Match the test to the failure type:**
  - *Discipline* failures (skipping a gate under pressure) → pressure scenarios that tempt the
    failure; PASS = the behavior holds. Used for the two approval gates.
  - *Grading/behavior-shaping* changes → **control vs treatment** arms on the same input;
    confirm the change moves behavior in the intended direction AND doesn't overcorrect (e.g.
    Evaluator must reject fake-green code, not just pass plain code). Used for the Evaluator
    re-weight.
  - *Conditional/technique* changes → functional smoke with the predicate present vs absent
    (e.g. knowledge base present vs absent). PASS = behaviors split on the predicate.
- **5 reps per arm** — single samples lie; variance is itself a signal.
- **Verify on DISK, never trust self-reports.** Agents claim "covered exactly once" or "I
  stopped at the gate"; parse the actual files (plan coverage counts, presence/absence of
  code past a gate) to confirm. Self-reports have matched disk truth so far, but the disk
  check is what makes a PASS trustworthy.
- **Always include a no-guidance / no-change control.** If the control doesn't exhibit the
  failure, there may be nothing to fix — see
  [[isolated-tests-may-not-reproduce-full-flow-failures]].

Not every change is behaviorally tested: pure structural/reference edits (parameterizing
build/test/lint commands, adding a plan field) are verified by coherence review (e.g. grep
that no hardcoded command survives) rather than pressure scenarios.

Related: [[hars-two-approval-gates]], [[hars-evaluator-functionality-hard-gate]],
[[hars-knowledge-base-retrieval]].
