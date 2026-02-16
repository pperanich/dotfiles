return {
  "wojciech-kulik/xcodebuild.nvim",
  -- Lazy-load on Swift/ObjC filetypes - plugin handles project detection internally
  ft = { "swift", "objc", "objcpp" },
  dependencies = {
    "ibhagwan/fzf-lua",
    "folke/snacks.nvim", -- (optional) to show previews

    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-tree.lua", -- (optional) to manage project files
    "stevearc/oil.nvim", -- (optional) to manage project files
    "nvim-treesitter/nvim-treesitter", -- (optional) for Quick tests support (required Swift parser)
    {
      "mfussenegger/nvim-lint",
      opts = {
        linters_by_ft = {
          swift = { "swiftlint" },
        },
        linters = {
          swiftlint = {
            cmd = "swiftlint",
            stdin = false,
            args = { "lint", "--force-exclude", "--quiet" },
            stream = "stdout",
            ignore_exitcode = true,
            parser = require("lint.parser").from_pattern(
              "([^:]+):(%d+):(%d+): (%a+): (.+)",
              { "file", "lnum", "col", "severity", "message" },
              {
                warning = vim.diagnostic.severity.WARN,
                error = vim.diagnostic.severity.ERROR,
              }
            ),
            -- Skip linting .swiftinterface files (Swift module interfaces)
            condition = function(ctx)
              return not vim.endswith(ctx.filename, ".swiftinterface")
            end,
          },
        },
      },
    },
    {
      "neovim/nvim-lspconfig",
      opts = {
        servers = {
          sourcekit = {
            cmd = { vim.trim(vim.fn.system("xcrun -f sourcekit-lsp")) } or nil,
          },
        },
      },
    },
    {
      "folke/trouble.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      init = function()
        -- Open Trouble's quickfix after Xcodebuild failures; close it on success
        vim.api.nvim_create_autocmd("User", {
          pattern = { "XcodebuildBuildFinished", "XcodebuildTestsFinished" },
          callback = function(ev)
            if not ev.data or ev.data.cancelled then
              return
            end
            if ev.data.success then
              pcall(function()
                require("trouble").close()
              end)
              return
            end
            local size = (vim.fn.getqflist({ size = 0 }).size or 0)
            if size > 0 then
              vim.cmd("Trouble qflist open focus=false")
            else
              pcall(function()
                require("trouble").close()
              end)
            end
          end,
        })
      end,
    },
    {
      "j-hui/fidget.nvim",
      opts = {
        notification = {
          window = {
            winblend = 0,
          },
        },
      },
    },
    {
      "nvim-lualine/lualine.nvim",
      opts = function(_, opts)
        -- Add Xcode status components to lualine
        local xcode_device = {
          function()
            if vim.g.xcodebuild_device_name then
              return " " .. vim.g.xcodebuild_device_name
            end
            return ""
          end,
          cond = function()
            return vim.g.xcodebuild_device_name ~= nil
          end,
          color = { fg = "#a6e3a1", gui = "bold" },
        }

        local xcode_os = {
          function()
            if vim.g.xcodebuild_os then
              return vim.g.xcodebuild_os
            end
            return ""
          end,
          cond = function()
            return vim.g.xcodebuild_os ~= nil
          end,
          color = { fg = "#89b4fa" },
        }

        local xcode_scheme = {
          function()
            if vim.g.xcodebuild_scheme then
              return " " .. vim.g.xcodebuild_scheme
            end
            return ""
          end,
          cond = function()
            return vim.g.xcodebuild_scheme ~= nil
          end,
          color = { fg = "#f9e2af", gui = "bold" },
        }

        local xcode_test_plan = {
          function()
            if vim.g.xcodebuild_test_plan then
              return "󰙨 " .. vim.g.xcodebuild_test_plan
            end
            return ""
          end,
          cond = function()
            return vim.g.xcodebuild_test_plan ~= nil
          end,
          color = { fg = "#cba6f7" },
        }

        -- Insert Xcode components into the right side of lualine
        -- These will only show when the variables are set (i.e., in Xcode projects)
        table.insert(opts.sections.lualine_x, 1, xcode_test_plan)
        table.insert(opts.sections.lualine_x, 1, xcode_scheme)
        table.insert(opts.sections.lualine_x, 1, xcode_os)
        table.insert(opts.sections.lualine_x, 1, xcode_device)
      end,
    },
    {
      "mfussenegger/nvim-dap",
      -- Only load this augmentation for Apple languages
      ft = { "swift", "objc", "objc++" },

      -- Merge with LazyVim's existing nvim-dap config (won't replace it)
      opts = function()
        local dap = require("dap")

        -- Hook Xcodebuild <-> DAP integration
        local ok, xcdap = pcall(require, "xcodebuild.integrations.dap")
        if ok then
          xcdap.setup()

          -- Set Xcode-specific keymaps here to avoid overwriting LazyVim's DAP keys
          -- These are additive and only load for Swift/ObjC filetypes
          vim.keymap.set("n", "<leader>dd", xcdap.build_and_debug, { desc = "Xcode: Build & Debug" })
          vim.keymap.set("n", "<leader>dD", xcdap.debug_without_build, { desc = "Xcode: Debug (No Build)" })
          vim.keymap.set("n", "<leader>dA", xcdap.debug_tests, { desc = "Xcode: Debug Tests" })
          vim.keymap.set("n", "<leader>dT", xcdap.debug_class_tests, { desc = "Xcode: Debug Class Tests" })
          vim.keymap.set(
            "n",
            "<leader>dL",
            xcdap.toggle_message_breakpoint,
            { desc = "Xcode: Toggle Message Breakpoint" }
          )
        end

        -- Small QoL tweak; LazyVim doesn't set this
        dap.defaults.fallback.switchbuf = "usetab,uselast"
      end,
    },
  },
  keys = {
    { "<leader>XA", "<cmd>XcodebuildPicker<CR>", desc = "Show Xcodebuild Actions" },
    { "<leader>Xf", "<cmd>XcodebuildProjectManager<CR>", desc = "Show Project Manager Actions" },

    { "<leader>Xb", "<cmd>XcodebuildBuild<CR>", desc = "Build Project" },
    { "<leader>XB", "<cmd>XcodebuildBuildForTesting<CR>", desc = "Build For Testing" },
    { "<leader>Xr", "<cmd>XcodebuildBuildRun<CR>", desc = "Build & Run Project" },

    { "<leader>Xt", "<cmd>XcodebuildTest<CR>", desc = "Run Tests" },
    {
      "<leader>Xt",
      "<cmd>XcodebuildTestSelected<CR>",
      mode = "v",
      desc = "Run Selected Tests",
    },
    { "<leader>XT", "<cmd>XcodebuildTestClass<CR>", desc = "Run Current Test Class" },
    { "<leader>X.", "<cmd>XcodebuildTestRepeat<CR>", desc = "Repeat Last Test Run" },

    { "<leader>Xl", "<cmd>XcodebuildToggleLogs<CR>", desc = "Toggle Xcodebuild Logs" },
    { "<leader>Xc", "<cmd>XcodebuildToggleCodeCoverage<CR>", desc = "Toggle Code Coverage" },
    { "<leader>XC", "<cmd>XcodebuildShowCodeCoverageReport<CR>", desc = "Show Code Coverage Report" },
    { "<leader>Xe", "<cmd>XcodebuildTestExplorerToggle<CR>", desc = "Toggle Test Explorer" },
    { "<leader>Xs", "<cmd>XcodebuildFailingSnapshots<CR>", desc = "Show Failing Snapshots" },

    { "<leader>Xp", "<cmd>XcodebuildPreviewGenerateAndShow<CR>", desc = "Generate Preview" },
    { "<leader>X<CR>", "<cmd>XcodebuildPreviewToggle<CR>", desc = "Toggle Preview" },

    { "<leader>Xd", "<cmd>XcodebuildSelectDevice<CR>", desc = "Select Device" },
    { "<leader>Xq", "<cmd>Telescope quickfix<CR>", desc = "Show QuickFix List" },

    { "<leader>Xx", "<cmd>XcodebuildQuickfixLine<CR>", desc = "Quickfix Line" },
    { "<leader>Xa", "<cmd>XcodebuildCodeActions<CR>", desc = "Show Code Actions" },
  },
  config = function()
    require("xcodebuild").setup({
      -- Enable code coverage
      code_coverage = {
        enabled = true,
      },
      -- File tree integrations - automatically guess target for new files
      integrations = {
        nvim_tree = {
          guess_target = true,
        },
        oil_nvim = {
          guess_target = true,
        },
        -- Enable iOS 17+ debugging support
        -- Requires pymobiledevice3 setup:
        --   1. Install: pip3 install pymobiledevice3
        --   2. Secure remote_debugger script from project root:
        --      sudo chmod 700 .nvim/xcodebuild/remote_debugger.py
        --      sudo chown root:wheel .nvim/xcodebuild/remote_debugger.py
        --   This prevents repeated password prompts when debugging on iOS 17+ physical devices
        pymobiledevice = {
          enabled = true,
        },
      },
      -- Fidget integration for build/test progress notifications
      logs = {
        notify = function(message, severity)
          local fidget = require("fidget")
          if fidget then
            fidget.notify(message, severity)
          end
        end,
        notify_progress = function(message)
          local fidget = require("fidget")
          if fidget then
            fidget.notify(message, vim.log.levels.INFO)
          end
        end,
      },
    })
  end,
}
