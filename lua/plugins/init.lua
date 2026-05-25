return {
  -- {
  --   "stevearc/conform.nvim",
  --   event = "BufWritePre",
  --   opts = require "configs.conform",
  -- },
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    opts = { ensure_installed = { "html", "css", "bash", "lua", "go", "groovy" } },
  },
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = {
        auto_trigger = true,
        keymap = {
          accept = "<C-a>",
        },
      },
    },
  },
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
            vertical = { location = "rightbelow", split_ratio = .5 },
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
    "smoka7/hop.nvim",
    version = "v2",
    opts = {},
  },
  {
    "stevearc/aerial.nvim",
    opts = {},
    lazy = false,
    config = function()
      require "configs.aerial"
    end,
    -- Optional dependencies
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
  },
  {
    "kdheepak/lazygit.nvim",
    lazy = true,
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    -- optional for floating window border decoration
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    -- setting the keybinding for LazyGit with 'keys' is recommended in
    -- order to load the plugin when the command is run for the first time
    keys = {
      { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
  },
  {},
  {
    "leoluz/nvim-dap-go",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
  },

  -- {
  --   "rest-nvim/rest.nvim",
  --   dependencies = {
  --     "nvim-treesitter/nvim-treesitter",
  --     opts = function(_, opts)
  --       opts.ensure_installed = opts.ensure_installed or {}
  --       table.insert(opts.ensure_installed, "http")
  --     end,
  --   },
  -- },

  -- {
  --   "ray-x/go.nvim",
  --   dependencies = { -- optional packages
  --     "ray-x/guihua.lua",
  --     "neovim/nvim-lspconfig",
  --     "nvim-treesitter/nvim-treesitter",
  --   },
  --   config = function()
  --     require("go").setup()
  --   end,
  --   event = { "CmdlineEnter" },
  --   ft = { "go", 'gomod' },
  --   build = ':lua require("go.install").update_all_sync()' -- if you need to install/update all binaries
  -- }
}
