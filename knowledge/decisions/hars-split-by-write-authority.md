# hars is split into six skills along write authority

The hars family is not divided by workflow phase or by size. Each skill is defined by **what it
is allowed to write to the plan file**, and its trigger boundaries follow from that.

| Skill | Writes |
|---|---|
| `hars-plan` | Creates the documents; the only writer of `Status: approved` |
| `hars-execute` | Task statuses, goal checkboxes, Iteration Log |
| `hars-verify` | The only writer of plan `Status: done`; persists knowledge |
| `hars-revise` | Reopens to `draft`, appends `## Amendments`, closes forks as `superseded` |
| `hars-status` | Nothing |
| `hars-grade` | Nothing |

**Why this axis:** the plan file is shared mutable state across sessions with no common memory,
so the failure mode that matters is two skills disagreeing about who may change a field. Slicing
by write authority makes every boundary checkable against one table
(`hars-plan/plan-format.md` §4) instead of by remembering a workflow.

## The two invariants it protects

- **Only `hars-plan` writes `approved`.** Consent has exactly one source. `hars-revise` can roll
  a plan back to `draft` or fork it, but it hands re-approval back rather than granting it —
  otherwise a "small edit" path would quietly become a second way to authorise unattended work.
- **Only `hars-verify` writes `done`.** Every task passing and the assembled system working are
  different claims. Keeping the integration gate in its own skill also makes it runnable on
  demand after a refactor or dependency bump, without dragging the execution loop along.

## Read-only skills earn their existence

`hars-status` and `hars-grade` were split out from `hars-execute` because asking a question
should not load a skill that writes state. `hars-status` doubles as the state-machine linter —
it is the only thing that routinely reads a whole plan, so it reports illegal statuses, header/
task disagreements, and coverage drift, and repairs none of them. `hars-grade` exposes the
Evaluator against arbitrary code, and its `PASSED` is explicitly *information*, never a task
transition — writing it into a plan would forge the evidence the harness exists to produce
honestly.

## Cost

Six skills share three prompt templates and one schema by **cross-skill relative links**
(`../hars-plan/plan-format.md`, `../hars-execute/evaluator.md`), which resolve through the
`~/.claude/skills` symlinks. That keeps a single normative copy of each contract, at the price
of the family having to be installed together.

Related: [[hars-plan-file-is-the-shared-state-machine]], [[hars-two-approval-gates]],
[[hars-integration-gate]].
