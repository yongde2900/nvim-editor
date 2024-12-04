return {
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre',
    opts = require "configs.conform",
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "html", "css", "bash", "lua" } },
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  { "szw/vim-maximizer", lazy = false },
  {
    "NvChad/nvterm",
    config = function(_, opts)
      require "base46.term"
      require("nvterm").setup {
        terminals = {
          shell = vim.o.shell,
          list = {},
          type_opts = {
            float = {
              relative = "editor",
              row = 0.25,
              col = 0.1,
              width = 0.8,
              height = 0.5,
              border = "rounded",
              winblend = 50,
            },
            horizontal = {
              relative = "win",
              row = 1,
              col = 1,
              width = 1,
              height = 0.5,
              border = "single",
            },
            vertical = { location = "center", split_ratio = 0.5 },
          },
        },
        behavior = {
          autoclose_on_quit = {
            enabled = false,
            confirm = true,
          },
          close_on_exit = true,
          auto_insert = true,
        },
      }
    end,
  },
  {
    "kevinhwang91/nvim-ufo",
    lazy = false,
    dependencies = { "kevinhwang91/promise-async" },
    config = function()
      require "configs.ufo"
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    opts = function()
      local cmp = require "cmp"
      local conf = require "nvchad.configs.cmp"

      local mymappings = {
        ["<Up>"] = cmp.mapping.select_prev_item(),
        ["<Down>"] = cmp.mapping.select_next_item(),
        ["<Tab"] = cmp.mapping(function()
          if cmp.visible() then
            cmp.select_next_item(999)
            cmp.select_prev_item(9999)
          end
        end, { "i", "s" }),
        -- ["<Tab>"] = cmp.mapping.confirm {
        --   behavior = cmp.ConfirmBehavior.Replace,
        --   select = true,
        -- },
      }
      conf.mapping = vim.tbl_deep_extend("force", conf.mapping, mymappings)
      return conf
    end,
  },
  {
    'smoka7/hop.nvim',
    version = "v2",
    opts = {
    }
  },
  {
    'stevearc/aerial.nvim',
    opts = {},
    lazy = false,
    config = function()
      require "configs.aerial"
    end,
    -- Optional dependencies
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons"
    },
  }
}
