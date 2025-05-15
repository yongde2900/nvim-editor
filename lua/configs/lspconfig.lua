local vim = vim
require("nvchad.configs.lspconfig").defaults()

vim.lsp.set_log_level("debug")


local lspconfig = require("lspconfig")
lspconfig.gopls.setup({
  settings = {
    gopls = {
      completeUnimported = true,
      usePlaceholders = true,
      analyses = {
        unusedparams = true,
      },
    }
  }
})


lspconfig.ts_ls.setup({
  on_attach = function(client, bufnr)
    -- 禁用 tsserver 的格式化功能，避免與其他格式化工具衝突
    client.server_capabilities.documentFormattingProvider = false
  end,
  settings = {
    javascript = {
      suggest = {
        autoImports = true,
      },
    },
  },
})

