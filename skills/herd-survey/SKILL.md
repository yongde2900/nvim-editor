---
name: herd-survey
description: Read-only broadcast survey across many repositories over Herdr. Asks one question of every project in the registry at once — one agent per repo, each answering from its own code — then aggregates the answers into a single comparable findings table. Use whenever the user wants the same question answered across several projects: "哪些專案還在用 X", "跨專案查一下", "which repos use this pattern", "does this bug exist elsewhere", "what would upgrading Y break", "who still depends on Z", or any audit, inventory, or impact assessment spanning more than two repos. It never writes to any project, so reach for it freely when the user is only asking. Do NOT use it to make a cross-project change (that is herd-sync), to explore one repo (search it directly), or as a generic "run this in another pane" helper (that is the herdr skill). Requires HERDR_ENV=1.
---

# Herd — Survey (Read-Only Broadcast)

Asks one question of N repos in parallel and returns one comparable answer table.

**This skill writes nothing to any project, ever.** That is not a side note — it is the entire
reason it is a separate skill from `herd-sync`. Because asking costs nothing and risks nothing, you
can point it at ten repos on a hunch. The moment a survey could also change something, every
invocation would need the caution (and the approval gate) that changing repos deserves.

**Role split:**
- **You = Coordinator** — read the registry, write the question down, spawn one surveyor per repo,
  collect answers from disk, aggregate into findings. This file is your playbook.
- **Surveyor (one per project, `kind=claude`)** — answers the question from one repo's code and
  writes an answer file. Brief: [surveyor.md](surveyor.md).

📐 **The project registry is defined in
[../herd-sync/registry-format.md](../herd-sync/registry-format.md)** (installed alongside this
skill, typically `~/.claude/skills/herd-sync/registry-format.md`). Read it, don't restate it.

## Trigger

User wants one question answered across several projects: "哪些專案還在用舊的 auth?", "跨專案查一下
誰依賴 sdk-go", "would bumping Postgres 14→16 break anything", "does this null-check bug exist in
the other services too".

If the answer is going to be followed by "…and fix them all", that second half is `herd-sync` —
survey first, then hand the findings to a contract.

### Floor — when NOT to spawn agents

Spawning N agents costs real time and tokens, so it has to buy something that a search wouldn't.
The dividing line is whether the question needs **judgment** or just **matching**.

- **"Which repos contain the string `LegacyAuthClient`?"** — that is matching. Grep the registry
  paths yourself and answer in one turn. Agents would add minutes and tell you the same thing.
- **"Which repos are still *effectively* on the old auth, including the ones that wrapped it?"** —
  that needs someone to read call sites and decide. Spawn surveyors.

Also skip the machinery for **one or two repos**: read them yourself. The aggregation table earns
its keep somewhere around three, when holding the comparison in your head stops working.

When you take the grep path, say so — "這個用搜尋就夠了，不用開 agent" — so the user knows the
cheaper route was a choice and not an omission.

## Workflow

```
Invocation
  → Phase S0  Ground: inside Herdr? registry readable? which repos are in scope?
  → Phase S1  Write QUESTION.md — one question, stated once, identical for everyone
  → Phase S2  Dispatch: one workspace + one surveyor per repo, all at once
  → Phase S3  Collect answers/<name>.md from disk
  → Phase S4  Aggregate into FINDINGS.md and report
```

No approval gate: nothing is being changed, so there is nothing to consent to.

---

## Phase S0 — Ground yourself

```bash
test "${HERDR_ENV:-}" = 1
```

Not inside Herdr → say so and stop.

Resolve `HERD_HOME` (`${HERD_HOME:-$HOME/.claude/herd}`) and use it for every herd path below,
including the absolute paths you hand to agents.

Read `$HERD_HOME/registry.md`. Missing or incomplete → follow the maintenance rules in
[registry-format.md](../herd-sync/registry-format.md); confirm any new row with the user.

Then settle **scope**. "Every project" usually means every project the user thinks is relevant, not
every row in the file. Show the list you are about to ask and let them trim it — surveying a repo
that was never in play produces a confidently irrelevant row in the findings table, which is worse
than a missing one because it invites a conclusion.

## Phase S1 — Write the question down

Create `$HERD_HOME/SURVEY-NNN-<slug>/QUESTION.md` (`NNN` zero-padded, counted over existing
`SURVEY-*` directories):

```markdown
# SURVEY-NNN — <brief>
Asked: <YYYY-MM-DD>
Scope: <project names>

## Question
<!-- Exactly what is being asked, in one or two sentences. -->

## Why
<!-- What decision this feeds. Surveyors use this to judge what counts as relevant — it is what
     makes them report the awkward edge case instead of rounding it to yes or no. -->

## What counts as evidence
<!-- Where to look and what would settle it: import sites, config files, call sites, dependency
     manifests, a specific function. Keeps five answers comparable instead of five interpretations
     of the question. -->

## Answer shape
<!-- The verdict vocabulary you want back, e.g. "yes / no / partially / not applicable". Pinning
     this down is what lets the findings table be a table. -->
```

Writing the question once, in a file every surveyor reads, is what makes the answers comparable. Ask
five agents five slightly different questions and the table you build from their answers is
meaningless — the differences between rows will be differences between the questions.

## Phase S2 — Dispatch surveyors

All at once — the answers are independent, and the whole point is a parallel snapshot.

For each project in scope:

```bash
herdr workspace create --cwd <project path> --label <project name> --no-focus
herdr agent start <project name> --kind claude --pane <root_pane_id>
herdr agent prompt <project name> "Read ~/.claude/skills/herd-survey/surveyor.md and <question path>, then answer for the repo you are in. Do not modify anything in this repository." --wait --timeout 600000
```

Take the pane from `.result.root_pane` in the `workspace create` response — parse it, never predict
it. Use the registry name as the agent name so the row, the agent, and `answers/<name>.md` all share
one identity. Keep `--no-focus` everywhere; the user stays in their pane.

The read-only instruction appears both here and in the brief on purpose. It is the one property of
this skill the user is relying on, and a prompt that is visible in the pane is easier for them to
audit than a rule buried in a file.

**`agent_blocked`** → the surveyor hit a permission dialog. Read it (`herdr agent read <name>`) and
tell the user. A read-only survey asking for write permission is worth looking at, not waving
through.

## Phase S3 — Collect the answers

`--wait` returning means the agent settled, not that it answered. **Read
`<Survey Dir>/answers/<name>.md` from disk.**

Do not grade from the pane. Agent panes commonly run on the alternate screen, where finished output
never enters scrollback and no `--lines` value recovers it — so a coordinator reading terminals
eventually reads a fragment and records it as a finding. `herdr agent get` / `agent read` answer
"is it stuck or did it ask something?", which is what panes are for.

No answer file and the agent is idle → it stopped without answering. Read its pane, find out why,
and record it as `unknown` with the reason. Never fill in an answer on a surveyor's behalf: a row
you wrote yourself is indistinguishable from evidence once it is in the table, and it is the row
someone will act on.

## Phase S4 — Aggregate and report

Write `<Survey Dir>/FINDINGS.md`:

```markdown
# SURVEY-NNN — Findings
Asked: <YYYY-MM-DD>
Question: <one line>

| Project | Verdict | Evidence | Caveats |
|---|---|---|---|
| api | yes | `internal/auth/client.go:42` | none |
| web | partially | `src/lib/auth.ts:17` wraps it | the wrapper may be dead code |
| sdk-go | not applicable | never had auth | — |

## What this means
<!-- The answer to the question the user actually asked, in prose. -->

## Not settled
<!-- Every `unknown`, every caveat that could flip a verdict, every repo that didn't answer. -->
```

Two habits make the difference between a table and a useful one:

**Keep the disagreements visible.** When three repos say yes and one says "partially, but", the
"but" is usually the finding — it is where the pattern is actually breaking down. Flattening it into
the majority answer throws away the only new information in the survey.

**Report the unknowns as prominently as the answers.** A survey's failure mode is quiet
incompleteness: four confident rows and one that silently didn't come back, read as "all clear".
If someone is about to decide based on this, what you *didn't* learn is part of the answer.

Then answer the user's question in prose and link the findings file. If the natural next step is
changing the repos you just surveyed, say so and hand off to `herd-sync` — the findings are most of
a contract's `Why` already.
