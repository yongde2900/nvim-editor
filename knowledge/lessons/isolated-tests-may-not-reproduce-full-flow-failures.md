---
title: Isolated subagent tests often don't reproduce failures seen in full flow
type: lessons
date: 2026-07-30
tags: [skills, testing, methodology, gotcha]
---

Twice while hardening hars, a failure observed in the *full* multi-phase flow did NOT
reproduce when the relevant step was tested in isolation with a clean control:

- **Coverage duplication:** a Planner acting in-role during the full flow once listed the same
  scenario under multiple sub-tasks. But an isolated Planner prompt on a deliberately
  cross-cutting spec produced exactly-once coverage 5/5 — the control never duplicated. The
  full-flow failure was most likely a context/pressure artifact of juggling the whole skill,
  not a Planner-prompt weakness.
- **Evaluator rejecting plain code:** the hypothesis was that the old originality-weighted
  rubric would reject correct-but-plain code. In isolation it passed such code 3/3
  (7.5–8.7) — the baseline "failure" didn't reproduce.

**The lesson:** absence of failure in an isolated micro-test is NOT proof of safety in the
full flow, and vice versa. Per `writing-skills`, "if the control doesn't exhibit the failure,
there's nothing to fix" — but that verdict only covers the *isolated* condition you actually
tested. Some guidance is therefore kept as low-cost insurance even when its necessity is
unproven in isolation (e.g. the plan's `## Coverage Check`), because the real failure lived in
a context the micro-test couldn't recreate.

**Practical takeaway:** when a change targets a failure first seen in full flow, either
reproduce it in a full-flow test, or be explicit that an isolated PASS doesn't clear the
full-flow risk — don't silently upgrade "isolated test passed" to "safe."

Related: [[validating-skill-changes-with-subagents]], [[hars-evaluator-functionality-hard-gate]].
