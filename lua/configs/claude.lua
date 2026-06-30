local M = {}

-- cmux surface (UUID) of the Claude tab we manage. Captured when opened via
-- M.open_window; otherwise resolved by scanning for the "✳ Claude Code" tab.
M.claude_surface = nil

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
2. Edge cases — empty input, null/nil, boundary values, max/min
3. Error cases — invalid input, failure modes, exception paths
4. Any concurrency or state-related scenarios if applicable

Use the same language and test framework already present in the project. Add a brief comment on what each test validates.]],
}

-- A canonical UUID, e.g. 309B0B44-22FA-492B-A575-77B4A807A260.
local UUID = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

local function cmux(args)
  local cmd = { "cmux" }
  vim.list_extend(cmd, args)
  return vim.fn.system(cmd)
end

local function rpc(method, params)
  cmux { "rpc", method, vim.json.encode(params) }
end

-- Resolve the Claude tab's surface UUID: prefer the one we opened, else scan the
-- pane's surfaces for the "Claude Code" tab title (set by the running CLI).
local function resolve_surface()
  if M.claude_surface then
    return M.claude_surface
  end
  local out = cmux { "list-pane-surfaces", "--id-format", "both" }
  for line in out:gmatch "[^\n]+" do
    if line:find "Claude Code" then
      local uuid = line:match("(" .. UUID .. ")")
      if uuid then
        M.claude_surface = uuid
        return uuid
      end
    end
  end
  return nil
end

function M.focus()
  local surface = resolve_surface()
  if surface then
    rpc("surface.focus", { surface_id = surface })
  end
end

-- Paste a prompt into the Claude tab via bracketed paste (handles multi-line
-- safely and submits once), unlike `cmux send` which turns every \n into Enter.
local function paste_prompt(prompt)
  local surface = resolve_surface()
  if not surface then
    vim.notify("No Claude tab found; open one with <leader>cc first", vim.log.levels.WARN)
    return
  end
  rpc("terminal.paste", { surface_id = surface, text = prompt })
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
          paste_prompt(prompt)
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

-- Open Claude Code in a new terminal tab of the current cmux workspace. We
-- create a plain terminal surface and run the `claude` CLI in it by sending the
-- command + Enter. nvim runs inside a cmux terminal, so CMUX_WORKSPACE_ID is
-- inherited and the new surface lands in the current workspace. We capture the
-- surface UUID so later sends can target this exact tab.
function M.open_window()
  local cwd = vim.fn.getcwd()
  local out = cmux {
    "--id-format", "both",
    "new-surface",
    "--type", "terminal",
    "--working-directory", cwd,
    "--focus", "true",
  }
  local uuid = out:match("(" .. UUID .. ")")
  local ref = out:match "surface:%d+"
  if not (uuid or ref) then
    vim.notify("Failed to open cmux terminal: " .. out, vim.log.levels.ERROR)
    return
  end
  M.claude_surface = uuid
  cmux { "send", "--surface", uuid or ref, "claude\n" }
  vim.notify("Opening Claude Code in a new cmux tab", vim.log.levels.INFO)
end

function M.send_selection() send_to_claude(nil) end
function M.review()        send_to_claude(prompts.review) end
function M.optimize()      send_to_claude(prompts.optimize) end
function M.explain()       send_to_claude(prompts.explain) end
function M.test()          send_to_claude(prompts.test) end

return M
