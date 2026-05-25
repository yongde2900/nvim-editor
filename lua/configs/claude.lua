local M = {}

function M.send_selection()
  local nvterm = require "nvterm.terminal"

  vim.cmd 'normal! "zy'
  local text = "@" .. vim.fn.fnamemodify(vim.fn.expand "%:p", ":.") .. "\n" .. vim.fn.getreg "z"

  local cwd = vim.fn.getcwd()
  local session = cwd:gsub("[/.-]", "_") .. "-claude"

  local pane = vim.fn
    .system("tmux list-panes -t " .. vim.fn.shellescape(session) .. " -F '#{pane_id}' 2>/dev/null")
    :gsub("%s+", "")

  if pane ~= "" then
    local tmpfile = vim.fn.tempname()
    vim.fn.writefile(vim.split(text, "\n", { plain = true }), tmpfile)
    vim.fn.system("tmux load-buffer " .. vim.fn.shellescape(tmpfile))
    vim.fn.system("tmux paste-buffer -t " .. pane)
    vim.fn.delete(tmpfile)
    nvterm.open "vertical"
    vim.notify("Sent to Claude Code", vim.log.levels.INFO)
  else
    vim.fn.setreg("+", text)
    vim.notify("Claude Code session not found, copied to clipboard", vim.log.levels.WARN)
  end
end

return M
