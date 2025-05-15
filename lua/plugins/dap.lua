local vim = vim
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local ui = require("dapui")

      dap.adapters.delve = function(callback, config)
        if config.mode == 'remote' and config.request == 'attach' then
          callback({
            type = 'server',
            host = config.host or '127.0.0.1',
            port = config.port or '38697'
          })
        else
          callback({
            type = 'server',
            port = '38697',
            executable = {
              command = 'dlv',
              args = { 'dap', '-l', '127.0.0.1:38697', '--log', '--log-output=dap', '--log-dest=/tmp/delve.log' },
              detached = vim.fn.has("win32") == 0,
            }
          })
        end
      end

      dap.configurations.go = {
        {
          type = "delve",
          name = "Debug-ams",
          request = "launch",
          mode = "debug",
          program = "${workspaceFolder}/cmd/wt-ams/main.go",
          env = {
            CC = "/usr/bin/cc",
            CXX = "/usr/bin/c++",
          }

        },
        {
          type = "delve",
          name = "Debug-report",
          request = "launch",
          mode = "debug",
          program = "${workspaceFolder}/cmd/wt-report/main.go",
          CC = "/usr/bin/cc",
          CXX = "/usr/bin/c++",

        },
        {
          type = "delve",
          name = "Debug-job",
          request = "launch",
          mode = "debug",
          program = "${workspaceFolder}/cmd/wt-job/main.go",
          CC = "/usr/bin/cc",
          CXX = "/usr/bin/c++",

        },
        {
          type = "delve",
          name = "Debut-test",
          request = "launch",
          mode = "debug",
          program = "${workspaceFolder}/cmd/wt-schedule/main.go",
          CC = "/usr/bin/cc",
          CXX = "/usr/bin/c++",

        },
        {
          type = "delve",
          name = "Debut-test",
          request = "launch",
          mode = "debug",
          program = "${workspaceFolder}/cmd/my-test/main.go",
          env = {
            CC = "/usr/bin/cc",
            CXX = "/usr/bin/c++",
          }

        },
        {
          type = "delve",
          name = "Debug-path",
          request = "launch",
          mode = "debug",
          program = function()
            return vim.fn.input('Path to program: ', vim.fn.getcwd() .. '/', 'file')
          end,
          CC = "/usr/bin/cc",
          CXX = "/usr/bin/c++",
        }
      }

      require("dapui").setup()
      require("nvim-dap-virtual-text").setup {
        display_callback = function(variable)
          local name = string.lower(variable.name)
          local value = string.lower(variable.value)

          -- if name:match "secret" or name:match "api" or value:match "secret" or value:match "api" then
          --   return "*****"
          -- end

          if #variable.value > 15 then
            return " " .. string.sub(variable.value, 1, 15) .. "... "
          end

          return " " .. variable.value
        end
      }

      -- Key mappings
      -- vim.keymap.set("n", "<leader>B", dap.toggle_breakpoint)
      -- vim.keymap.set("n", "<leader>gB", dap.run_to_cursor)
      -- vim.keymap.set("n", "<leader>?", function()
      --   require("dapui").eval(nil, { enter = true })
      -- end)
      -- vim.keymap.set("n", "<F1>", dap.continue)
      -- vim.keymap.set("n", "<F2>", dap.step_into)
      -- vim.keymap.set("n", "<F3>", dap.step_over)
      -- vim.keymap.set("n", "<F4>", dap.step_out)
      -- vim.keymap.set("n", "<F5>", dap.step_back)
      -- vim.keymap.set("n", "<F13>", dap.restart)

      -- DAP UI listeners
      dap.listeners.before.attach.dapui_config = function()
        ui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        ui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        ui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        ui.close()
      end
    end
  }
}
