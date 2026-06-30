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
    opts = { ensure_installed = { "html", "css", "javascript", "typescript", "bash", "lua", "go", "groovy", "python", "java" } },
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
            vertical = { location = "rightbelow", split_ratio = 0.5 },
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
  {
    "coder/claudecode.nvim",
    -- Load shortly after the UI is up so we can auto-start the server.
    event = "VeryLazy",
    opts = {
      -- Never open an embedded terminal in Neovim; always talk to the
      -- external `claude` connected via :ClaudeCodeStart + /ide over WebSocket.
      terminal = { provider = "none" },
    },
    config = function(_, opts)
      require("claudecode").setup(opts)
      -- Auto-start the WebSocket server, but skip if another nvim already
      -- runs one for this same workspace (each lock file is named by port and
      -- records its workspaceFolders). Avoids multiple servers advertising the
      -- same project, which makes `/ide` ambiguous about which nvim to attach.
      local cwd = vim.fn.getcwd()
      local ide_dir = vim.fn.expand "~/.claude/ide"
      local already = false
      for _, f in ipairs(vim.fn.glob(ide_dir .. "/*.lock", true, true)) do
        local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(f), "\n"))
        if ok and data.workspaceFolders and vim.tbl_contains(data.workspaceFolders, cwd) then
          already = true
          break
        end
      end
      if not already then
        vim.cmd "ClaudeCodeStart"
      end
    end,
    keys = {
      { "<leader>oa", nil, desc = "AI/Claude Code" },
      { "<leader>ac", "<cmd>ClaudeCodeStart<cr>", desc = "Start Claude server" },
      { "<leader>aq", "<cmd>ClaudeCodeStop<cr>", desc = "Stop Claude server" },
      { "<leader>aS", "<cmd>ClaudeCodeStatus<cr>", desc = "Claude server status" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
      },
      -- Diff management
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },
  {
    "leoluz/nvim-dap-go",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
  },
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
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
