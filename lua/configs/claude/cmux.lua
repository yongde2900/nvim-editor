-- cmux backend for configs/claude.lua — the fallback used when this nvim is not
-- running inside Herdr.
--
-- cmux has no notion of a named agent, so the Claude tab is tracked by its
-- surface UUID: the one we opened, or whichever surface in this pane carries the
-- "Claude Code" title the CLI sets. That handle is weaker than Herdr's agent
-- name — it is lost on nvim restart and it cannot tell whether Claude is idle or
-- sitting on an approval dialog, so prompts are pasted blind.

local M = {}

M.claude_surface = nil

-- True when this nvim is running inside a cmux surface.
function M.available()
  return vim.env.CMUX_SURFACE_ID ~= nil and vim.fn.executable "cmux" == 1
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Claude / cmux" })
end

-- A canonical UUID, e.g. 309B0B44-22FA-492B-A575-77B4A807A260.
local UUID = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

local function cmux(args)
  local cmd = { "cmux" }
  vim.list_extend(cmd, args)
  return vim.fn.system(cmd)
end

local function rpc(method, params)
  return cmux { "rpc", method, vim.json.encode(params) }
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

-- Bind a Claude that was started by hand. cmux has no rename, so "attaching" is
-- just remembering the surface the caller names.
function M.attach(target)
  target = target or vim.fn.input "cmux surface id or ref: "
  if target == "" then
    return
  end
  M.claude_surface = target
  notify("Bound surface " .. target)
end

function M.focus()
  local surface = resolve_surface()
  if surface then
    rpc("surface.focus", { surface_id = surface })
  end
end

-- Paste a prompt into the Claude tab via bracketed paste (handles multi-line
-- safely and submits once), unlike `cmux send` which turns every \n into Enter.
function M.prompt(prompt)
  local surface = resolve_surface()
  if not surface then
    notify("No Claude tab found; open one with <leader>cc first", vim.log.levels.WARN)
    return
  end
  rpc("terminal.paste", { surface_id = surface, text = prompt })
end

-- Open Claude Code in a new terminal tab of the current cmux workspace. We
-- create a plain terminal surface and run the `claude` CLI in it by sending the
-- command + Enter. nvim runs inside a cmux terminal, so CMUX_WORKSPACE_ID is
-- inherited and the new surface lands in the current workspace. We capture the
-- surface UUID so later sends can target this exact tab.
function M.open_window()
  if resolve_surface() then
    M.focus()
    return
  end
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
    notify("Failed to open cmux terminal: " .. out, vim.log.levels.ERROR)
    return
  end
  M.claude_surface = uuid
  cmux { "send", "--surface", uuid or ref, "claude\n" }
  notify "Opening Claude Code in a new cmux tab"
end

-- cmux exposes no agent state, so this only answers "which surface are we
-- pointed at" — not whether Claude there is idle, busy, or blocked.
function M.status()
  local surface = resolve_surface()
  if not surface then
    notify("No Claude tab found (workspace " .. tostring(vim.env.CMUX_WORKSPACE_ID) .. ")", vim.log.levels.WARN)
    return
  end
  notify("Claude tab at surface " .. surface .. " — cmux reports no agent state")
end

return M
