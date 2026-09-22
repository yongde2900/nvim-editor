---
name: herd-sync
description: Cross-project change coordination over Herdr. Negotiates one written interface contract between two or more repos, holds a single human approval gate on it, dispatches one Herdr agent per project to implement its side in its own workspace, collects their reports from disk, and verifies the seams end-to-end. Use whenever a change spans more than one repository — the user says "herd", "herd sync", "跨專案", "跨 repo", "要先改 B 才能改 A", or describes an API/proto/schema/SDK change that a consumer must follow, or the same feature landing in frontend and backend at once. Also use when the user is about to have one agent edit a repo it does not live in. Do NOT use it for read-only questions across repos (that is herd-survey), for work inside a single repo (hars-plan / hars-execute, or just make the change), or as a generic "run this in another pane" helper (that is the herdr skill). Requires HERDR_ENV=1.
---

# Herd — Sync (Cross-Project Coordination)

Coordinates one change across several repos. It is a **thin layer**: it owns the shared interface,
the dispatch, and the seams between projects. What happens *inside* each project — whether that
needs a full `hars` run or three edits and a test — belongs to that project's own agent.

**Role split:**
- **You = Coordinator** — read the registry, negotiate the contract, hold Gate 1, spawn one agent
  per project, collect reports from disk, run the integration check yourself, hold Gate 2. This
  file is your playbook. You do not edit any project's code.
- **Implementer (one per project, `kind=claude`, `model=sonnet`)** — implements its project's side
  of the contract and writes a report. Brief: [implementer.md](implementer.md). It decides its own
  internal process.

The split matches the `hars` family: the expensive judgment lives in deciding what to build and
whether it is really done — which is yours — while carrying out an already-frozen interface is the
step that gets spawned once per project, so it runs on sonnet.

📐 **The contract's schema, both state machines, and the field-ownership table are in
[contract-format.md](contract-format.md)** (installed alongside this skill, typically
`~/.claude/skills/herd-sync/contract-format.md`). **The project registry is defined in
[registry-format.md](registry-format.md).** Read them if anything surprises you; do not restate
or widen them here.

## Trigger

User says "herd", "herd sync", "跨專案", "跨 repo", "同步到 A 和 B", or describes a change where a
repo's public surface moves and something else consumes it.

Read-only questions across repos ("哪些專案還在用舊的 auth?") are `herd-survey` — it cannot write
to any project, which is exactly why it is safe to point at ten repos.

### Floor — when NOT to run herd-sync

This costs a contract file, a human approval gate, N workspaces, N agents, and an integration
pass. That price buys protection against one specific failure — two repos drifting apart across a
shared surface — so it is worth paying only when that surface is actually in play. Ask three
questions:

1. **Does more than one repo change?** If only one repo's files move, this is single-project work
   however many repos are in the conversation. Do it there.
2. **Is there a surface between them that this change moves?** Two unrelated fixes that happen to
   land the same afternoon are two tasks, not a contract. There must be something one side
   produces and the other consumes.
3. **Is that surface actually changing?** If the interface already exists and is stable, the
   consumer's work is ordinary single-project work against a published API. No negotiation needed.

**Any "no" → don't use herd-sync.** Make the change directly, or use `hars-plan` in the one repo
that is really moving.

## Workflow

```
Invocation
  → Phase H0  Ground: inside Herdr? registry readable? paths real? trees clean?
              (resuming an existing HERD-NNN → jump to the phase its Status implies)
  → Phase H1  Contract: pick the shape, write CONTRACT.md as draft
  → Phase H2  ▲ GATE 1 — human approves the contract. Only they may stamp `approved`.
  → Phase H3  Dispatch: one workspace + one agent per project, in dependency order
  → Phase H4  Collect: read reports/<name>.md from disk; diff each against the Interface
              • any rejection → Status: stalled, back to Gate 1
  → Phase H5  Integrate: run the Integration Check in your own neutral pane
              • fails → Status: stalled, back to Gate 1 (or re-dispatch one project)
  → Phase H6  ▲ GATE 2 — verified. Report what changed where; commit/push only if asked.
```

Every phase re-derives its position from `CONTRACT.md` on disk, so an interrupted run resumes by
reading the file rather than by remembering anything.

---

## Phase H0 — Ground yourself

You are about to start agents that edit repos. Being wrong about *which* repos is the one mistake
here with no cheap undo, so establish the facts before anything moves.

```bash
test "${HERDR_ENV:-}" = 1
```

Not inside Herdr → say so and stop. There is no fallback; this skill's entire dispatch mechanism
is the Herdr session.

Then:

1. **Resolve `HERD_HOME`** (`${HERD_HOME:-$HOME/.claude/herd}`) and use that value for every herd
   path below, including the absolute paths you hand to agents.
2. **Read `$HERD_HOME/registry.md`.** Missing, or missing a project the user named → follow the
   maintenance rules in [registry-format.md](registry-format.md). Confirm any new row with the user
   before writing it.
3. **Check each participating path** exists and is a git repo.
4. **Check each working tree.** A tree that is already dirty makes Gate 2 ambiguous — neither you
   nor the user will be able to tell your agent's changes from what was there this morning. Show
   the user what is uncommitted and ask how to proceed before dispatching.
5. **Resuming?** Look for an existing `$HERD_HOME/HERD-*` directory for this change. If one
   exists, its `Status` says where to rejoin — don't start a second contract for the same work.

## Phase H1 — Write the contract

First pick the shape, because it decides the dispatch order in H3:

- **`upstream-first`** — one project owns the surface and others consume it. The producer has to
  land before consumers can compile against it. Set `Depends on` accordingly.
- **`parallel`** — every project builds its own side of an agreed surface simultaneously, and they
  meet at integration. Faster, and only safe because the interface is frozen and precise.

Choose `parallel` when the interface can be pinned down in writing well enough that two agents who
never talk will land on the same thing. When it can't — when the shape of the API will only become
clear once someone tries to build it — that is `upstream-first`, and the honest reason to say so
is right there.

Then write `CONTRACT.md` per [contract-format.md](contract-format.md) §2. Three things earn the
most from your attention:

**The `Interface` section is the whole product of this phase.** Each implementer builds against it
alone, with no ability to ask you what you meant. Write real signatures, real route paths, real
field names and types, real error cases — the level of detail where `user_id` versus `userId` is
already settled. Vagueness here doesn't stay vague; it becomes two incompatible guesses.

**Each `Done when` must be checkable by someone who didn't do the work.** "Implements the new
endpoint correctly" gives you nothing to verify in H4. "`GET /v2/users/:id` returns 200 with the
schema above and 404 for unknown ids; covered by a test in `handlers_test.go`" does.

**The `Integration Check` is what makes this more than paperwork.** Write the actual steps: what to
start, what to call, what the answer must be. If there is genuinely nothing runnable, say
`none — contract-level only` and say why; don't invent a ceremony.

Leave `Status: draft`.

## Phase H2 — ▲ Gate 1: human approves the contract

Show the user the contract — at minimum the `Interface`, the per-project `Delivers` / `Done when`
lines, and the `Integration Check`. Say plainly what is about to happen: N agents in N workspaces
editing N repos.

This is the cheapest point in the whole workflow to be wrong. After it, the interface is frozen and
disagreeing with it costs a rejection, a stall, and a return trip through this gate.

**Only the user stamps `Status: approved`.** Do not stamp it yourself, do not treat "sounds good"
about something else as approval, and do not dispatch against a `draft`. That stamp is the only
record that a human agreed to move these repos.

## Phase H3 — Dispatch one agent per project

One workspace per project: an agent gets a full-height tab in its own repo's directory, its name
shows in the sidebar, and nothing it does disturbs your pane.

For each project, in dependency order (`upstream-first`: a project waits until everything in its
`Depends on` is `delivered`; `parallel`: all at once):

```bash
herdr workspace create --cwd <project path> --label <project name> --no-focus
```

Take the pane from `.result.root_pane` — parse it out of the JSON, never predict it. Then start the
agent under the project's registry name, so the registry row, the agent, the contract section and
the report all share one identity:

```bash
herdr agent start <project name> --kind claude --pane <root_pane_id> -- --model sonnet
```

Native agent arguments only go after `--`; anything before it is Herdr's own. The model is not
negotiable per-project — an implementer on a different model against the same frozen interface is
one more axis on which two repos can diverge.

Then hand it the two paths and nothing else:

```bash
herdr agent prompt <project name> "Read ~/.claude/skills/herd-sync/implementer.md and <contract path>, then implement the '### <project name>' section for the repo you are in." --wait --timeout 900000
```

Keeping the prompt to two paths is deliberate: the brief and the contract are files that both of
you can re-read, quote, and check. Anything you type into the prompt instead exists only in that
pane's scrollback, where neither of you can get it back later.

Set each project's `Status: dispatched` and the contract's `Status: dispatched`. Append to the
`Log`. Keep the user's focus in your own pane throughout — `--no-focus` everywhere.

**If `agent prompt` returns `agent_blocked`**, the agent is sitting on an approval or question
dialog. Read it with `herdr agent read <name>` and ask the user. Never answer a permission prompt
on their behalf — it is very often a request to do something outside the contract.

## Phase H4 — Collect the reports

`agent prompt --wait` returns when the agent settles. That tells you it stopped moving; it does not
tell you what it did. **Read `<Coordination Dir>/reports/<name>.md` from disk.**

This is invariant 2 in [contract-format.md](contract-format.md) §4 and the most tempting one to
skip: the pane is right there and seems to have the answer. It doesn't. Agents commonly run on the
terminal's alternate screen, where finished output never enters scrollback and no `--lines` value
will recover it — so a coordinator grading on terminal reads eventually grades a truncated
fragment and calls a half-finished change delivered. Use `herdr agent get` / `agent read` to answer
"is it stuck, or did it ask something?" — that is what the pane is good for.

No report and the agent is idle → it stopped without delivering. Read the pane to find out why and
tell the user; do not write the report for it.

For each report:

1. **Diff `Interface as actually implemented` against the contract's `Interface`.** Names, types,
   paths, status codes. This check is why the report asks for it — it catches divergence before the
   two sides ever meet, when it is still one agent's small fix.
2. **Re-check `Done when` yourself**, from disk or by running the stated command. The report is a
   claim; you are confirming it.
3. **Read `For the others`** — startup order, migrations, ports, files to regenerate. This feeds
   H5, and in `upstream-first` it may be something the next project needs to know.

Matches and checks out → `Status: delivered`. Diverges → send the agent back with the specific
discrepancy; it is still live and still has its context.

**Any `Status: rejected`** → contract `Status: stalled`. Do not negotiate with the rejection
yourself and do not patch the interface to accommodate it: take the agent's `Would work instead` to
the user and go back through Gate 1. A rejection usually means the implementer learned something
true about the code that you didn't know when you wrote the contract.

## Phase H5 — Integration check

All projects `delivered` → contract `Status: integrating`.

Run the `Integration Check` **yourself, in a neutral pane you create**. Not in a project's
workspace: those panes belong to agents that have a stake in the answer, and an agent that has just
declared itself done is the worst available judge of whether the seam actually works.

```bash
herdr pane split --current --direction right --cwd <path> --no-focus
herdr pane run <pane_id> "<integration command>"
herdr pane wait-output <pane_id> --match "<expected marker>" --timeout 120000
herdr pane read <pane_id> --source recent-unwrapped --lines 200
```

Split right from a wide pane, down from a narrow one (`herdr pane layout --pane "$HERDR_PANE_ID"`).
Ordinary commands write to the normal screen, so reading this pane *is* reliable — the alternate
screen problem is an agent-pane problem.

Passes → `Status: verified`, log it, go to H6.
Fails → `Status: stalled`. Read the output, work out which side of the seam is wrong, and say so.
If it is one project's implementation, re-prompt that agent — it is still live. If the contract
itself was wrong, that is Gate 1 again.

## Phase H6 — ▲ Gate 2: hand the working trees back

Nothing is committed. Say so explicitly, and report:

- Which repos have uncommitted changes, and the one-line summary of each from its report
- What the integration check actually ran and what it printed
- Anything from `For the others` that survives this change — a migration that must run in
  production, a regenerated file, a new env var

Then ask whether to commit, and in what order. **Commit and push only on an explicit instruction,
per repo.** Cross-project changes have a landing order that depends on deploys, releases, and
review processes you cannot see from here; getting it wrong can break production for real users
even when every individual repo is correct.

If anything in the contract deserves to outlive the change — a decision and its reasoning, a
gotcha — offer to persist it with `save-to-knowledge-base` or into the owning repo's docs. The
coordination directory is scratch; it is not where design decisions should end up living.

---

## Things that will go wrong

**An agent edits a repo that isn't its own.** Its report should say so under `What I changed`, and
paths outside its `Path` are the tell. Stop, tell the user, and don't let the other project's agent
keep working on a tree someone else has touched.

**Two projects both claim to own the same surface.** That is a contract-writing failure, not an
implementation one. One `Delivers`, the other `Depends on`. Fix it at Gate 1.

**An agent name is taken.** Names are unique among live agents and are cleared when the agent
exits. A collision means a previous run's agent is still alive — `herdr agent list` will show you.
Reuse it or let the user close it; don't invent `api-2`, because then the report filename, the
contract section, and the agent stop agreeing with each other.

**You are asked to just do it without a contract.** Two repos, a small change, why the ceremony —
sometimes that is right, and the floor above is how you check. But if the floor says herd-sync
applies, the contract is the cheap part: it is one file, and it is the only artifact that survives
your context running out halfway through.
