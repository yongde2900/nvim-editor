---
title: hars has two independent human approval gates (BDD, then plan)
type: decisions
date: 2026-07-30
tags: [hars, approval-gate, workflow]
---

hars requires the user to explicitly approve **twice** before any code is written: once on
the BDD spec (end of Phase 1), then again on the plan (end of Phase 2). Each is a hard STOP —
the Coordinator ends its turn and waits.

**What was decided:** the two gates are independent and equally binding. **Approving the BDD
is NOT approving the plan.** The skill wording explicitly forbids: inferring plan approval
from an earlier "go" on the BDD; treating deadline / "move fast" / "don't babysit this" as
consent; spawning the Executor to "get a head start" while waiting; and treating a
plan-change request as approval.

**Why:** the whole point of harness mode is quality gates, so time pressure must not be
allowed to collapse them. The specific "one 'go' = blanket approval" rationalization was the
main risk for the second gate, so the counters target it directly.

**Evidence:** both gates were pressure-tested with fresh-context subagents under a hard
deadline ("15–20 min demo, don't wait on me"). Gate 1 held 5/5 and Gate 2 held 5/5 — every
run stopped and waited, none fabricated consent, verified on disk (BDD file present, no plan
or code past the gate; plan present, no code past the gate). The Gate 2 runs quoted the exact
counter-wording ("approving the spec is not approving the plan").

Related: [[hars-bdd-single-source-of-truth]], [[validating-skill-changes-with-subagents]].
