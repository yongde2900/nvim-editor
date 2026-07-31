# Knowledge Base Index

This is the map of the knowledge base. Each entry links to a self-contained
Markdown file. Files are grouped by type; scan the section you need and follow
the link. Keep this index in sync with the files — add a line when a file is
created, refresh the hook when content changes.

## Decisions
- [BDD scenarios are hars's single source of truth](decisions/hars-bdd-single-source-of-truth.md) — scenarios flow spec→plan→test→grading; Coverage Check enforces exactly-once mapping
- [Two independent human approval gates](decisions/hars-two-approval-gates.md) — BDD then plan; approving the spec is not approving the plan; both pressure-tested 5/5
- [Evaluator: functionality is a 50% hard gate](decisions/hars-evaluator-functionality-hard-gate.md) — dropped "originality"; functionality grounded in executed test results, not source-reading
- [Whole-system integration gate (Phase 6)](decisions/hars-integration-gate.md) — per-task passes aren't "done"; re-verify cross-cutting scenarios on the assembled system
- [Knowledge-base retrieval + save-back loop](decisions/hars-knowledge-base-retrieval.md) — Phase 0 retrieves ./knowledge/, threads Known Context, Phase 6 saves back

## Conventions
- [Validating skill changes with subagents](conventions/validating-skill-changes-with-subagents.md) — control/treatment fresh-context tests, 5 reps, verify on disk not self-reports

## Lessons
- [Isolated tests may not reproduce full-flow failures](lessons/isolated-tests-may-not-reproduce-full-flow-failures.md) — an isolated PASS doesn't clear a failure first seen in full flow
