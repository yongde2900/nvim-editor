local M = {}

local function fix_semicolons(bufnr)
  local diags = vim.tbl_filter(function(d)
    return d.message and d.message:find('insert ";"') ~= nil
  end, vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR }))

  if #diags == 0 then return end

  -- 從後往前插，避免插入後行號/字元位置跑掉
  table.sort(diags, function(a, b)
    if a.lnum ~= b.lnum then return a.lnum > b.lnum end
    return a.col > b.col
  end)

  for _, d in ipairs(diags) do
    local lsp_range = d.user_data and d.user_data.lsp and d.user_data.lsp.range
    if lsp_range then
      local line = lsp_range["end"].line
      local char = lsp_range["end"].character
      vim.api.nvim_buf_set_text(bufnr, line, char, line, char, { ";" })
    end
  end
end

local format_on_save = true

local function on_attach(_, bufnr)
  vim.keymap.set("n", "<leader>tf", function()
    format_on_save = not format_on_save
    vim.notify("Java format on save: " .. (format_on_save and "ON" or "OFF"), vim.log.levels.INFO)
  end, { buffer = bufnr, desc = "Toggle Java format on save" })

  vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = bufnr,
    callback = function()
      fix_semicolons(bufnr)
      if format_on_save then
        vim.lsp.buf.format { async = false }
      end
      require("jdtls").organize_imports()
    end,
  })
end

function M:setup()
  local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
  local workspace_dir = "/Users/jimmy/development/jdtls_data/" .. project_name
  local lombokpath = ""
  local config = {
    cmd = {
      "/opt/homebrew/opt/openjdk@21/bin/java",

      "-Declipse.application=org.eclipse.jdt.ls.core.id1",
      "-Dosgi.bundles.defaultStartLevel=4",
      "-Dlog.protocol=true",
      "-Dlog.level=ALL",
      "-Xmx1g",
      "--add-opens",
      "java.base/java.util=ALL-UNNAMED",
      "--add-opens",
      "java.base/java.lang=ALL-UNNAMED",
      "-javaagent:" .. vim.fn.expand("~") .. "/.m2/repository/org/projectlombok/lombok/1.18.46/lombok-1.18.46.jar",

      "-jar",
      "/opt/homebrew/Cellar/jdtls/1.58.0/libexec/plugins/org.eclipse.equinox.launcher_1.7.100.v20251111-0406.jar",

      "-configuration",
      "/opt/homebrew/Cellar/jdtls/1.58.0/libexec/config_mac",

      "-data",
      workspace_dir,
    },
    root_dir = require("jdtls.setup").find_root { ".git", "mvnw", "gradlew" },
    on_attach = on_attach,

    settings = {
      java = {
        sources = {
          organizeImports = {
            starThreshold = 3,
            staticStarThreshold = 3,
          },
        },
      },
    },

    init_options = {
      bundles = {},
    },
  }
  require("jdtls").start_or_attach(config)
end

return M
