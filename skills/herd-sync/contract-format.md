# CONTRACT file format (normative)

The contract is the only thing the coordinator and the project agents share. Each project agent
starts with a fresh context, in a different repo, and gets **nothing but the absolute path to
this file**. So its schema, its state machine, and its field ownership are defined here, once.

`herd-sync` links here instead of restating it. `herd-survey` never touches this file at all.

---

## 1. Where it lives

```
$HERD_HOME/                          # defaults to ~/.claude/herd — see registry-format.md
├── registry.md
└── HERD-NNN-<slug>/
    ├── CONTRACT.md                  # this file's schema
    └── reports/
        └── <project-name>.md        # one per participating project, written by that project's agent
```

`NNN` is a zero-padded counter over existing `HERD-*` directories. The directory is central and
repo-neutral on purpose: no participating repo owns the contract, so no repo's review process
becomes a gate on the other's work, and a half-finished coordination never leaves stray files in
someone's working tree.

The cost of that choice is that the contract is not version-controlled. It is a coordination
artifact with a lifecycle measured in hours, not a design document — if something in it deserves
to outlive the change, it belongs in the affected repo's own docs or in `knowledge/`, and moving
it there is part of finishing.

---

## 2. File skeleton

```markdown
# HERD-NNN — <brief>
Created: <YYYY-MM-DD>
Status: draft
Shape: upstream-first | parallel
Coordination Dir: /Users/jamie/.claude/herd/HERD-NNN-<slug>
Integration Check: <command the coordinator runs itself, or "none — contract-level only">

## Why
<!-- One to three sentences. What breaks, or what becomes possible, once every project below
     has landed its side. An implementer who disagrees with the interface needs this to
     propose something better rather than just complying. -->

## Interface
<!-- The normative shared surface, in whatever notation actually pins it down: signatures,
     endpoint + method + status codes, proto/JSON schema, SQL columns, env var names, error
     cases. Precise enough that two agents who never talk can both hit it.
     FROZEN once Status is approved — see §4. -->

## Projects

### <name>
Path: <absolute path, from the registry>
Depends on: <name(s) | none>
Delivers: <the observable thing another project may rely on>
Done when: <checkable from disk or by running a command — not "implemented correctly">
Status: pending
Report: reports/<name>.md

### <name>
...

## Integration Check
<!-- The steps the coordinator runs in its own neutral pane once every project is delivered:
     what to start, what to call, what the answer must be. Write "none — contract-level only"
     when there is genuinely nothing runnable, and say why. -->

## Log
| When | Event |
|---|---|
| <YYYY-MM-DD HH:MM> | <what happened> |
```

---

## 3. State machines

### Contract status

```
draft ──(human approves at Gate 1)──▶ approved ──(agents dispatched)──▶ dispatched
                                                                            │
                                    ┌───────────────────────────────────────┤
                                    ▼                                       ▼
                               integrating ──(integration check passes)──▶ verified
                                    │
                                    └──(a project rejects, or integration fails)──▶ stalled
                                                                                       │
                                                        (human re-approves a revision) ─┘
                                                                     └──▶ approved
```

`verified` is the terminal state reached by evidence. It is deliberately **not** called `done`:
nothing is committed or pushed at that point. What happens to the working trees afterwards is
Gate 2, and it belongs to the user.

### Per-project status

```
pending ──(agent started and prompted)──▶ dispatched ──▶ delivered
                                               │
                                               └──▶ rejected
```

- `delivered` — the agent wrote `reports/<name>.md` claiming its `Done when` is met, **and the
  coordinator confirmed it from disk**. Both halves are required; see §4.
- `rejected` — the agent cannot honor the interface as written and said why in its report. This
  is a legitimate, useful outcome, not a failure: an implementer who has read the actual code is
  often the first to discover the contract is wrong. It stalls the contract and returns to Gate 1.

---

## 4. Field ownership

| Field | Who writes it | Why it matters |
|---|---|---|
| `Why`, `Interface`, `Projects`, `Integration Check` | The coordinator, during the contract phase only | Written before anyone is dispatched |
| `Status: approved` | **Only the human, at Gate 1** | Consent has one source |
| `Status: dispatched / integrating / stalled / verified` | The coordinator, from evidence | Never optimistically ahead of the evidence |
| Per-project `Status` | The coordinator | The agent writes a claim; the coordinator writes the status |
| `reports/<name>.md` | **Only that project's agent** | The coordinator never authors a report on an agent's behalf — a report it wrote itself is not evidence of anything |
| `Log` | The coordinator, append-only | So a later session can reconstruct what happened |

### Two invariants worth not breaking

**1. Only the human writes `approved`.**
Every downstream phase refuses to run against a contract that isn't stamped. Without that check,
a chain of agents could rewrite interfaces across several repos that no human ever looked at.

**2. Only a file on disk promotes a project to `delivered`.**
Not a terminal read, not an agent's `idle` state, not a confident-sounding response in a pane.
This is not pedantry: agents commonly run on the terminal's alternate screen, where completed
output leaves no scrollback and cannot be recovered at any `--lines` count — so a coordinator
that grades on terminal reads will sooner or later grade on a truncated fragment and call a
half-finished change delivered. The pane tells you whether an agent is *still moving*. The file
tells you what it *did*.

### The Interface freeze

Once `Status: approved`, the `Interface` section is frozen. An implementer who finds it
unworkable reports `rejected` with a reason; it does not edit the contract, and neither does the
coordinator on its own.

This is the rule the whole design exists to enforce. The characteristic cross-project failure is
not that someone writes bad code — it's that one side quietly adjusts the shared surface to suit
itself, ships something that works locally, and the other side finds out at integration time or
later in production. Freezing the interface means a disagreement surfaces as an explicit
`rejected` in front of the human who can settle it, at the point where settling it is cheap.

Revising a frozen interface is a normal event, not an exception. Amend the `Interface` section,
set `Status: draft`, append to the `Log`, and go back through Gate 1 — including for projects
that already reported `delivered`, since their delivery was against the old surface.
