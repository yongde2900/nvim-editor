local M = {}

local nvterm = require "nvterm.terminal"

local function get_filename()
  return vim.fn.fnamemodify(vim.fn.expand "%:p", ":.")
end

local function get_selection()
  vim.cmd 'normal! "zy'
  return vim.fn.getreg "z"
end

local prompts = {
  review = [[
Review the above code and report only real issues (no theoretical risks). Cover:
1. Bugs & logic errors — flawed conditions, off-by-one, unintended flows
2. Security — injection, auth flaws, sensitive data exposure, input validation
3. Performance — N+1 queries, unnecessary loops, memory leaks, O(n²) algorithms
4. Error handling — missing null checks, unhandled exceptions, resource cleanup

Format each finding as: [severity: critical/high/medium] [line] — issue → fix suggestion]
Skip style/formatting nits.]],

  optimize = [[
Analyze the above code for performance. For each issue found:
- Identify current time/space complexity (Big-O)
- Explain why it's a bottleneck
- Provide an optimized rewrite with the improved complexity

Focus on: algorithm efficiency, unnecessary iterations, redundant computation, memory allocation, caching opportunities, and database query patterns (N+1, missing indexes).]],

  explain = [[
Explain the above code to a senior engineer unfamiliar with this module:
1. What is the overall purpose and responsibility of this code?
2. Walk through the key logic step by step
3. Highlight any non-obvious design decisions or tradeoffs
4. Call out any hidden assumptions or constraints the code relies on]],

  test = [[
Write comprehensive tests for the above code. Include:
1. Happy path — normal expected usage
2. Edge cases — empty input, null/nil, boundary values, max/min
3. Error cases — invalid input, failure modes, exception paths
4. Any concurrency or state-related scenarios if applicable

Use the same language and test framework already present in the project. Add a brief comment on what each test validates.]],
}

local function send_to_claude(prompt)
  local text = ("@" .. get_filename() .. "\n" .. get_selection()):gsub("\n+$", "")
  if prompt then
    text = text .. "\n\n" .. prompt
  end

  local cwd = vim.fn.getcwd()
  local session = cwd:gsub("[/.-]", "_") .. "-claude"

  local pane = vim.fn
    .system("tmux list-panes -t " .. vim.fn.shellescape(session) .. " -F '#{pane_id}' 2>/dev/null")
    :gsub("%s+", "")

  local vertical_term = nil
  for _, term in ipairs(nvterm.list_active_terms()) do
    if term.type == "vertical" then
      vertical_term = term
      break
    end
  end

  if vertical_term then
    if vim.fn.bufwinnr(vertical_term.buf) == -1 then
      nvterm.show_term(vertical_term)
    end
  else
    vertical_term = nvterm.new "vertical"
  end

  if pane ~= "" then
    vim.fn.system { "tmux", "set-buffer", text }
    vim.fn.system("tmux paste-buffer -p -t " .. pane)
    vim.notify("Sent to Claude Code", vim.log.levels.INFO)
  else
    vim.fn.setreg("+", text)
    vim.notify("Claude Code session not found, copied to clipboard", vim.log.levels.WARN)
  end

  local winid = vim.fn.bufwinid(vertical_term.buf)
  if winid ~= -1 then
    vim.api.nvim_set_current_win(winid)
  end
end

function M.send_selection() send_to_claude(nil) end
function M.review()        send_to_claude(prompts.review) end
function M.optimize()      send_to_claude(prompts.optimize) end
function M.explain()       send_to_claude(prompts.explain) end
function M.test()          send_to_claude(prompts.test) end

return M
