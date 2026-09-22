# Project registry format (normative)

`$HERD_HOME/registry.md` is the one place that answers "which projects exist and where".
Both `herd-sync` and `herd-survey` read it; neither can function without it, because a
coordinator that guesses at paths will happily dispatch an agent into the wrong repo.

**`HERD_HOME` defaults to `~/.claude/herd`.** Resolve it once at the start of a run —

```bash
echo "${HERD_HOME:-$HOME/.claude/herd}"
```

— and use that value everywhere, including in the absolute paths you hand to dispatched agents.
The variable exists so a run can be pointed at an isolated herd (a test session, or a separate
registry for work versus personal repos) without editing any skill. Everything below is relative
to the resolved value; this file writes `$HERD_HOME/…` to mean exactly that.

## File skeleton

```markdown
# Herd project registry

| Name | Path | Role | Build | Test | Notes |
|---|---|---|---|---|---|
| api      | /Users/jamie/code/api      | Go backend, owns the OpenAPI spec | `go build ./...`    | `go test -race ./...` | source of truth for wire types |
| web      | /Users/jamie/code/web      | React frontend                    | `pnpm build`        | `pnpm test`           | consumes api's generated client |
| sdk-go   | /Users/jamie/code/sdk-go   | published Go client               | `go build ./...`    | `go test ./...`       | semver; breaking change = major |
```

An optional `## Shared context` section may follow the table, for facts that hold across **every**
project — a code-generation step they all run, a library they all depend on, a credential they all
need, a property every test suite shares. It exists so a contract does not have to rediscover the
same thing three times, and so a fact that is true everywhere is stated once rather than copied
into three `Notes` cells where two of them will go stale.

Keep it to what is genuinely universal. A fact about one project belongs in that project's `Notes`;
anything an implementer needs for one specific change belongs in the contract, not here.

## Fields

| Field | Meaning | Rules |
|---|---|---|
| `Name` | The project's identity everywhere in herd | Must match `[a-z][a-z0-9_-]{0,31}` |
| `Path` | Absolute path to the repo root | Must exist and be a git repo |
| `Role` | One line: what this project is, in what stack | Free prose; read by the coordinator to write a sensible contract |
| `Build` | Command that compiles it | Backticked; run from `Path` |
| `Test` | Command that runs its suite | Backticked; run from `Path` |
| `Notes` | Ownership, conventions, gotchas | Free prose; optional |

**`Name` is deliberately constrained to the Herdr agent-name pattern.** One identity runs the
whole way through: the registry row, the Herdr agent (`herdr agent start api ...`), the contract's
`### api` section, and `reports/api.md`. When every layer uses the same token, a coordinator
reading a report never has to guess which pane produced it — and a stale agent name from a
previous run collides loudly instead of silently attaching to the wrong project.

## Maintenance

The registry is yours; the skills may extend it but never invent it.

- **Missing file** → stop and offer to create it from the projects the user names. Do not scan
  the disk for repos and guess: a registry populated by guesswork looks authoritative and isn't.
- **Named project not in the registry** → ask the user for its path, confirm it exists and is a
  git repo, then append a row. Confirm the row with them before writing it, because everything
  downstream trusts this file without re-checking.
- **Row exists but `Path` is gone** → stop. Do not search for a moved repo; a wrong guess here
  means dispatching an agent that edits an unrelated codebase.

Keep rows for projects you actually coordinate across. A registry that lists every repo you own
makes `herd-survey` broadcast to places you didn't mean to ask.
