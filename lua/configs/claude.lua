local M = {}

-- Claude Code runs in its own tab of the *same* Herdr workspace as this Neovim,
-- registered with Herdr as a named agent. The name is the durable handle: pane
-- and tab IDs are reassigned when a pane is moved between workspaces, but the
-- name follows the agent until it exits.
M.config = {
  kind = "claude",
  -- Switch to the Claude tab right after opening it.
  focus_on_open = true,
  -- `agent start` only returns once Herdr has detected Claude and considers it
  -- ready for input, so this has to cover CLI startup.
  start_timeout_ms = 60000,
  -- How long to wait for the new tab's shell to reach its prompt before giving
  -- up. `agent start` rejects a pane that is still running rc files.
  shell_timeout_ms = 15000,
}

M.agent = nil -- agent name we own, e.g. "claude-w5"
M.pane_id = nil
M.tab_id = nil
M.workspace = nil

local prompts = {
  review = [[
Review the selected code and report only real issues (no theoretical risks). Cover:
1. Bugs & logic errors — flawed conditions, off-by-one, unintended flows
2. Security — injection, auth flaws, sensitive data exposure, input validation
3. Performance — N+1 queries, unnecessary loops, memory leaks, O(n²) algorithms
4. Error handling — missing null checks, unhandled exceptions, resource cleanup

Format each finding as: [severity: critical/high/medium] [line] — issue → fix suggestion]
Skip style/formatting nits.]],

  optimize = [[
Analyze the selected code for performance. For each issue found:
- Identify current time/space complexity (Big-O)
- Explain why it's a bottleneck
- Provide an optimized rewrite with the improved complexity

Focus on: algorithm efficiency, unnecessary iterations, redundant computation, memory allocation, caching opportunities, and database query patterns (N+1, missing indexes).]],

  explain = [[
Explain the selected code to a senior engineer unfamiliar with this module:
1. What is the overall purpose and responsibility of this code?
2. Walk through the key logic step by step
3. Highlight any non-obvious design decisions or tradeoffs
4. Call out any hidden assumptions or constraints the code relies on]],

  test = [[
Write comprehensive tests for the selected code. Include:
1. Happy path — normal expected usage
2. Any concurrency or state-related scenarios if applicable

Use the same language and test framework already present in the project. Add a brief comment on what each test validates.]],
}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Claude / Herdr" })
end

local function in_herdr()
  return vim.env.HERDR_ENV == "1"
end

-- Decode a herdr CLI invocation. Returns the `result` table, or nil plus the
-- `error` object ({ code, message }) that herdr writes to stderr with status 1.
local function decode(proc)
  local payload = (proc.stdout ~= nil and proc.stdout ~= "") and proc.stdout or (proc.stderr or "")
  local ok, body = pcall(vim.json.decode, payload)
  if not ok or type(body) ~= "table" then
    return nil, { code = "cli_error", message = vim.trim(payload) ~= "" and vim.trim(payload) or ("exit " .. proc.code) }
  end
  if proc.code ~= 0 or body.error then
    return nil, body.error or { code = "cli_error", message = "exit " .. proc.code }
  end
  return body.result or {}
end

local function cmd(args)
  local argv = { "herdr" }
  vim.list_extend(argv, args)
  return argv
end

local function herdr(args)
  return decode(vim.system(cmd(args), { text = true }):wait())
end

-- Never block the editor on Claude's startup or on a prompt round-trip.
local function herdr_async(args, on_done)
  vim.system(cmd(args), { text = true }, function(proc)
    local result, err = decode(proc)
    if on_done then
      vim.schedule(function()
        on_done(result, err)
      end)
    end
  end)
end

-- Prefer the live caller context over the inherited HERDR_WORKSPACE_ID, which
-- goes stale if this nvim's pane was moved into another workspace.
local function workspace()
  if M.workspace then
    return M.workspace
  end
  local res = herdr { "pane", "current", "--current" }
  M.workspace = (res and res.pane and res.pane.workspace_id) or vim.env.HERDR_WORKSPACE_ID
  return M.workspace
end

-- Agent names must match [a-z][a-z0-9_-]{0,31} and be unique among live agents,
-- so scope ours to the workspace: one Claude tab per workspace.
local function agent_name()
  local ws = (workspace() or "nvim"):lower():gsub("[^a-z0-9_-]", "")
  return "claude-" .. (ws ~= "" and ws or "nvim")
end

local function live_agents()
  local res = herdr { "agent", "list" }
  return (res and res.agents) or {}
end

local function bind(a)
  M.agent, M.pane_id, M.tab_id = a.name, a.pane_id, a.tab_id
  return M.agent
end

-- Resolve the agent to talk to, strictly by name. Herdr keeps the name on the
-- agent until it exits, so this still finds our Claude after nvim restarts — no
-- title scanning, and no chance of hijacking somebody else's Claude that merely
-- happens to share this workspace. Bind one of those with M.attach.
local function resolve()
  if not in_herdr() then
    return nil
  end
  local want = M.agent or agent_name()
  for _, a in ipairs(live_agents()) do
    if a.name == want then
      return bind(a)
    end
  end
  M.agent, M.pane_id = nil, nil
  return nil
end

-- Claim an already-running Claude — a unique agent name or the pane ID hosting
-- it — by renaming it to ours. Use after starting Claude by hand.
function M.attach(target)
  if not in_herdr() then
    notify("Not running inside Herdr", vim.log.levels.WARN)
    return
  end
  target = target or vim.fn.input "Herdr agent name or pane id: "
  if target == "" then
    return
  end
  local _, err = herdr { "agent", "rename", target, agent_name() }
  if err then
    notify("attach failed: " .. (err.message or err.code), vim.log.levels.ERROR)
    return
  end
  M.agent = agent_name()
  if resolve() then
    notify("Bound " .. M.agent .. " (" .. tostring(M.pane_id) .. ")")
  end
end

-- `tab create` returns as soon as the pane exists, but `agent start` refuses a
-- pane that is not "an available shell" — the shell itself in the foreground at
-- its prompt. A freshly spawned zsh is still sourcing rc files at that point, so
-- poll until its own pid is the whole foreground group.
local function await_shell(pane, deadline, on_ready)
  herdr_async({ "pane", "process-info", "--pane", pane }, function(res)
    local info = res and res.process_info
    local fg = (info and info.foreground_processes) or {}
    local settled = info
      and info.shell_pid
      and info.shell_pid == info.foreground_process_group_id
      and #fg == 1
      and fg[1].pid == info.shell_pid

    if settled then
      on_ready(true)
    elseif vim.uv.now() >= deadline then
      on_ready(false)
    else
      vim.defer_fn(function()
        await_shell(pane, deadline, on_ready)
      end, 150)
    end
  end)
end

function M.focus()
  local target = resolve()
  if target then
    herdr_async { "agent", "focus", target }
  elseif M.tab_id then
    herdr_async { "tab", "focus", M.tab_id }
  end
end

-- Hand a prompt to Claude. `agent prompt` honors the pane's live bracketed-paste
-- mode and appends Enter itself, so multi-line prompts arrive whole and submit
-- once — and it refuses outright, rather than typing blind, when Claude is
-- sitting on an approval or question dialog.
function M.prompt(prompt)
  local target = resolve()
  if not target then
    notify("No Claude agent found; open one with <leader>cc first", vim.log.levels.WARN)
    return
  end
  herdr_async({ "agent", "prompt", target, prompt }, function(_, err)
    if not err then
      return
    end
    if err.code == "agent_blocked" then
      notify("Claude is waiting on a dialog — answer it, then resend", vim.log.levels.WARN)
    else
      notify("agent prompt failed: " .. (err.message or err.code), vim.log.levels.ERROR)
    end
  end)
end

-- Send the visual selection as an at-mention over the /ide WebSocket, then once
-- it's accepted, paste the prompt into the Claude tab and focus it.
--
-- Timing: ClaudeCodeSendComplete fires at *acceptance*, but the at-mention is
-- delivered on a ~50ms debounce and Claude needs a moment to render the `@ref`
-- into its prompt box. We defer the paste so the prompt doesn't submit before the
-- reference lands. The event only fires when a Claude client is connected, so a
-- short fallback timer tears down the one-shot autocmd if nothing was sent.
local function send_to_claude(prompt)
  local fired = false
  local id = vim.api.nvim_create_autocmd("User", {
    pattern = "ClaudeCodeSendComplete",
    once = true,
    callback = function()
      fired = true
      vim.defer_fn(function()
        if prompt then
          M.prompt(prompt)
        end
        M.focus()
      end, 250)
    end,
  })
  vim.defer_fn(function()
    if not fired then
      pcall(vim.api.nvim_del_autocmd, id)
    end
  end, 3000)

  -- '< and '> are set: visual mode just ended before this callback ran.
  vim.cmd "'<,'>ClaudeCodeSend"
end

-- Open Claude Code in a new tab of the current Herdr workspace. `tab create`
-- hands back a root pane sitting at a shell prompt; `agent start` then launches
-- the CLI in it and only returns once Herdr has detected Claude and considers it
-- ready for input, which is why it runs off the main loop.
function M.open_window()
  if not in_herdr() then
    notify("Not running inside Herdr — no session to attach to", vim.log.levels.WARN)
    return
  end
  if resolve() then
    M.focus()
    return
  end

  local cwd = vim.fn.getcwd()
  local res, err = herdr {
    "tab", "create",
    "--workspace", workspace(),
    "--cwd", cwd,
    "--label", vim.fn.fnamemodify(cwd, ":t"),
    M.config.focus_on_open and "--focus" or "--no-focus",
  }
  if not res then
    notify("tab create failed: " .. ((err and (err.message or err.code)) or "unknown"), vim.log.levels.ERROR)
    return
  end

  M.tab_id = res.tab and res.tab.tab_id
  M.pane_id = res.root_pane and res.root_pane.pane_id
  if not M.pane_id then
    notify("tab create returned no root pane", vim.log.levels.ERROR)
    return
  end

  local name = agent_name()
  local pane = M.pane_id
  notify("Starting Claude Code in " .. M.tab_id .. "…")

  await_shell(pane, vim.uv.now() + M.config.shell_timeout_ms, function(ready)
    if not ready then
      notify("Shell in " .. pane .. " never reached a prompt", vim.log.levels.ERROR)
      return
    end
    herdr_async({
      "agent", "start", name,
      "--kind", M.config.kind,
      "--pane", pane,
      "--timeout", tostring(M.config.start_timeout_ms),
    }, function(started, start_err)
      if started and started.agent then
        bind(started.agent)
        notify("Claude Code ready as " .. M.agent .. " (" .. M.pane_id .. ")")
      elseif start_err and start_err.code == "agent_not_ready" then
        -- Herdr keeps the name reserved for reads and key sends even though
        -- Claude came up blocked, e.g. on a trust prompt.
        M.agent = name
        notify("Claude started but is blocked — finish setup in " .. pane, vim.log.levels.WARN)
      else
        notify("agent start failed: " .. ((start_err and (start_err.message or start_err.code)) or "unknown"), vim.log.levels.ERROR)
      end
    end)
  end)
end

-- Where are we pointed, and what is Claude doing right now?
function M.status()
  if not in_herdr() then
    notify("Not running inside Herdr", vim.log.levels.WARN)
    return
  end
  local target = resolve()
  if not target then
    notify("No Claude agent bound (workspace " .. tostring(workspace()) .. ")", vim.log.levels.WARN)
    return
  end
  local res = herdr { "agent", "get", target }
  local a = res and res.agent
  notify(("%s — %s @ %s (%s)"):format(target, a and a.agent_status or "?", a and a.pane_id or "?", a and a.tab_id or "?"))
end

function M.send_selection() send_to_claude(nil) end
function M.review()        send_to_claude(prompts.review) end
function M.optimize()      send_to_claude(prompts.optimize) end
function M.explain()       send_to_claude(prompts.explain) end
function M.test()          send_to_claude(prompts.test) end

return M
