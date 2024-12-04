require("copilot").setup({
  suggestion = { enabled = false },
  panel = { enabled = false },
  formatting = {
    format = lspkind.cmp_format({
      mode = "symbol",
      max_width = 50,
      symbol_map = { Copilot = "" }
    })
  }
})
