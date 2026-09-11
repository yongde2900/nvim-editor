-- Claude Code control surface for this nvim.
--
-- The selection hand-off (`ClaudeCodeSend`) goes over the CLI's own /ide
-- WebSocket and works anywhere. Everything else — opening Claude in a tab,
-- focusing it, pasting a prompt into it — needs the terminal multiplexer this
-- nvim is running under, so it is delegated to a backend:
--
--   configs/claude/herdr.lua   preferred: named agents, readiness + dialog aware
--   configs/claude/cmux.lua    fallback: surface UUIDs, no agent state
--
-- The backend is chosen from the environment at first use. Neither present is
-- not an error, just a no-op with a warning: the at-mention still lands, there
-- is simply no Claude tab to drive.

local M = {}

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
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Claude" })
end

-- Herdr wins when both are available: a nvim pane inside Herdr can still see
-- inherited CMUX_* vars, and the cmux backend would then drive the wrong app.
local candidates = {
  { name = "herdr", module = "configs.claude.herdr" },
  { name = "cmux", module = "configs.claude.cmux" },
}

-- Resolved once: these env vars are inherited at startup and do not change
-- under a running nvim.
local picked, searched = nil, false

local function backend(quiet)
  if not searched then
    searched = true
    for _, c in ipairs(candidates) do
      local ok, mod = pcall(require, c.module)
      if ok and mod.available() then
        picked = mod
        M.backend_name = c.name
        break
      end
    end
  end
  if not picked and not quiet then
    notify("No herdr or cmux session — nothing to drive Claude in", vim.log.levels.WARN)
  end
  return picked
end

M.backend = backend
M.backend_name = nil

function M.open_window()
  local b = backend()
  if b then
    b.open_window()
  end
end

-- Focus is always a side effect of something else, so it stays quiet when there
-- is no backend — the caller has already warned.
function M.focus()
  local b = backend(true)
  if b then
    b.focus()
  end
end

function M.prompt(prompt)
  local b = backend()
  if b then
    b.prompt(prompt)
  end
end

function M.status()
  local b = backend()
  if b then
    b.status()
  end
end

function M.attach(target)
  local b = backend()
  if b then
    b.attach(target)
  end
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

function M.send_selection() send_to_claude(nil) end
function M.review()        send_to_claude(prompts.review) end
function M.optimize()      send_to_claude(prompts.optimize) end
function M.explain()       send_to_claude(prompts.explain) end
function M.test()          send_to_claude(prompts.test) end

return M
