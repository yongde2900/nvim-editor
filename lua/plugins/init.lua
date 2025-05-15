return {
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre',
    opts = require "configs.conform",
  },
  {
    "nvim-treesitter/nvim-treesitter",
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
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
    },
    build = "make tiktoken",                          -- Only on MacOS or Linux
    opts = {
      prompts = {
        ExpalinMer = {
          prompt = "Write an explanation for the selected code as paragraphs of text. Use 正體中文",
          mapping = '<leader>cex'
        },
        ReviewMer = {
          prompt =
          "You are a software developer responsible for conducting code reviews in the Engineering department of a technology/software company. After reviewing a code submission, generate a comprehensive report summarizing the findings. Include information such as identified issues, recommendations for improvement, areas of strength, and overall code quality assessment. The report should be well-structured, easy to understand, and provide actionable feedback to the developer. use mandarin",
          mapping = '<leader>crv'
        },
        OptimizeMer = {
          prompt = "Optimize the selected code to improve performance and readability with 正體中文",
          mapping = '<leader>cop'
        },
        CommitMer = {
          prompt =
          "Write commit message for the change with commitizen convention，使用以下格式`[${feature name}][${type}]${commite message}`,其中type包括`Feat`, `Fix`, `Style`, `Docs`,`Refactor`, `Test`, `Chore`,並且feature name和commite message使用正體中文",
          mapping = "<leader>ccm"
        }
      }
    },
  },
  {
    "ray-x/go.nvim",
    dependencies = { -- optional packages
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup()
    end,
    event = { "CmdlineEnter" },
    ft = { "go", 'gomod' },
    build = ':lua require("go.install").update_all_sync()' -- if you need to install/update all binaries
  }
}
