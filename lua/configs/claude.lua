local M = {}

function M.send_selection()
  local nvterm = require "nvterm.terminal"

  vim.cmd 'normal! "zy'
  local text = ("@" .. vim.fn.fnamemodify(vim.fn.expand "%:p", ":.") .. "\n" .. vim.fn.getreg "z"):gsub("\n+$", "")

  local cwd = vim.fn.getcwd()
  local session = cwd:gsub("[/.-]", "_") .. "-claude"

  -- 獲取tmux session pane
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

  -- 跳到該window
  local winid = vim.fn.bufwinid(vertical_term.buf)
  if winid ~= -1 then
    vim.api.nvim_set_current_win(winid)
  end
end

return M
