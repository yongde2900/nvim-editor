require "nvchad.mappings"
local vim = vim
local dap = require "dap"
local dapui = require "dapui"
local dapgo = require "dap-go"
-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>nh", ":nohl<CR>", { desc = "Clear highlights" })
map("n", "x", '"_x', { desc = "Delete without yanking" })
map("i", "jk", "<ESC>", { desc = "jk to escape" })
map("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
map("n", "U", ":redo<CR>", { desc = "Redo" })

--window manage
map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Equalize window sizes" })
map("n", "<leader>sx", ":close<CR>", { desc = "Close window" })
map("n", "<leader>sm", ":MaximizerToggle<CR>", { desc = "Maximize window" })
map("n", "<left>", "<C-w>h", { desc = "Move to left window" })
map("n", "<right>", "<C-w>l", { desc = "Move to right window" })
map("n", "<Up>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<Down>", "<C-w>j", { desc = "Move to lower window" })
--nvim terminal
local nvterm = require "nvterm.terminal"
map("t", "<C-/>", function()
  nvterm.toggle "float"
end, { desc = "Toggle terminal" })
map("n", "<C-/>", function()
  nvterm.toggle "float"
end, { desc = "Toggle terminal" })
map("n", "<C-\\>", function()
  nvterm.toggle "vertical"
end)
map("t", "<C-\\>", function()
  nvterm.toggle "vertical"
end)
local function term_nav(dir)
  local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n><C-w>" .. dir, true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
end
map("t", "<C-b>", function()
  term_nav "h"
end, { desc = "Terminal: move left" })
map("t", "<C-w>j", function()
  term_nav "j"
end, { desc = "Terminal: move down" })
map("t", "<C-w>k", function()
  term_nav "k"
end, { desc = "Terminal: move up" })
map("t", "<C-w>l", function()
  term_nav "l"
end, { desc = "Terminal: move right" })

--tab
map("n", "<leader>to", ":tabnew<CR>", { desc = "Open a new tab" })
map("n", "<leader>tx", ":tabclose<CR>", { desc = "Close current tab" })
map("n", "<leader>h", ":tabn<CR>", { desc = "Go to next tab" })
map("n", "<leader>l", ":tabp<CR>", { desc = "Go to previous tab" })

--lspconfig
map("n", "gd", ":Telescope lsp_definitions<CR>", { desc = "Go to definition" })
map("n", "gi", ":Telescope lsp_implementations<CR>", { desc = "Go to implementation" })
map("n", "gr", ":Telescope lsp_references<CR>", { desc = "Go to references" })
map("n", "gI", ":Telescope lsp_incoming_calls<CR>", { desc = "Go to references" })
map("n", "go", ":Telescope lsp_outgoing_calls<CR>", { desc = "Go to references" })
map("n", "gt", ":Telescope lsp_type_definitions<CR>", { desc = "Go to references" })
map("n", "gD", ":Telescope diagnostics<CR>", { desc = "Go to references" })

--code action
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actions" })
map("n", "<leader>doc", function()
  vim.lsp.buf.code_action {
    filtter = function(action)
      return action.title:match "Browse documentation"
    end,
    apply = true,
  }
end, { desc = "Open documentation" })
map("n", "<leader>gl", vim.diagnostic.open_float)

map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })

--git
map("n", "<leader>gm", ":Telescope git_commits<CR>", { desc = "Git commits" })
map("n", "<leader>gbm", ":Telescope git_bcommits<CR>", { desc = "Git buffer commits" })
map("n", "<leader>gs", ":Telescope git_status<CR>", { desc = "Git status" })
map("n", "<leader>gbc", ":Telescope git_branches<CR>", { desc = "Git branches" })
map("n", "<leader>gsh ", ":Telescope git_stash<CR>", { desc = "Git stash" })
map("n", "<leader>gch", "/<<<<<<<CR>")
map("n", "<leader>gcf", "/>>>>>><CR>")
map("n", "<leader>gcm", "/======<CR>")

--dap
map("n", "<leader>bk", dap.toggle_breakpoint)
map("n", "<leader>gbk", dap.run_to_cursor)
map("n", "<leader>?", function()
  require("dapui").eval(nil, { enter = true })
end)
map("n", "<leader>1", dap.continue)
map("n", "<leader>2", dap.step_into)
map("n", "<leader>3", dap.step_over)
map("n", "<leader>4", dap.step_out)
map("n", "<leader>5", dap.step_back)
map("n", "<leader>6", dap.restart)
map("n", "<leader>0", dapui.toggle)
map("n", "<leader>dt", dapgo.debug_test)
map("n", "<leader>dtl", dapgo.debug_last_test)

-- Actions
map("n", "<leader>rh", function()
  require("gitsigns").reset_hunk()
end)

map("n", "<leader>ph", function()
  require("gitsigns").preview_hunk()
end)

map("n", "<leader>gb", function()
  package.loaded.gitsigns.blame_line()
end)

map("n", "<leader>td", function()
  require("gitsigns").toggle_deleted()
end)

map("n", "]c", function()
  if vim.wo.diff then
    return "]c"
  end
  vim.schedule(function()
    require("gitsigns").next_hunk()
  end)
  return "<Ignore>"
end)

map("n", "[c", function()
  if vim.wo.diff then
    return "[c"
  end
  vim.schedule(function()
    require("gitsigns").prev_hunk()
  end)
  return "<Ignore>"
end)

map("n", "<leader>fjs", ":%!jq .<CR>")

-- Send visual selection to Claude Code tmux session
local claude = require "configs.claude"
map("v", "<leader>cs", claude.send_selection, { desc = "Send selection to Claude Code" })
map("v", "<leader>cr", claude.review, { desc = "review selection to Claude Code" })
map("v", "<leader>co", claude.optimize, { desc = "optimize selection to Claude Code" })
map("v", "<leader>ce", claude.explain, { desc = "explain selection to Claude Code" })
map("v", "<leader>ct", claude.test, { desc = "test selection to Claude Code" })

-- place this in one of your configuration file(s)
local hop = require "hop"
local directions = require("hop.hint").HintDirection
map("n", "f", function()
  hop.hint_char1 { direction = directions.AFTER_CURSOR, current_line_only = true }
end)
map("n", "F", function()
  hop.hint_char1 { direction = directions.BEFORE_CURSOR, current_line_only = true }
end)

map("n", "t", function()
  hop.hint_lines_skip_whitespace()
end)
