---
title: BDD scenarios are hars's single source of truth
type: decisions
date: 2026-07-30
tags: [hars, bdd, workflow, testing]
---

The hars ("Harness-Driven Development") skill is built around **Gherkin BDD scenarios as
the one artifact that flows through the whole pipeline**: the Coordinator writes a
`BDD-NNN.feature` spec (Phase 1), the Planner maps each scenario into exactly one sub-task's
Expected Goals (Phase 2), the Executor writes one test per scenario (Phase 3), and the
Evaluator grades the code against those same scenarios (Phase 4).

**What was decided:** scenarios are the single grading standard, referenced by name at every
stage. A `## Coverage Check` section in the plan file forces every scenario to map to exactly
one sub-task — none dropped, none duplicated.

**Why:** it makes the work traceable end-to-end (requirement → plan → test → verdict) and
kills spec drift — the thing being graded IS the spec, so there is no second, divergent set
of "goals" to fall out of sync. The earlier design had the Planner invent free-form
"Expected Goals" independently; that was replaced because those goals could contradict the
brief and gave the Evaluator a standard nobody had approved.

Because scenarios are this load-bearing, Phase 1 has a **scenario quality self-check** (each
scenario must have Given/When/Then, an observable/checkable `Then`, be independently testable,
and cover a single behavior) — garbage scenarios would poison every downstream stage.

Related: [[hars-two-approval-gates]], [[hars-evaluator-functionality-hard-gate]].
