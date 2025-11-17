return {
  "wojciech-kulik/xcodebuild.nvim",
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
        -- Open Trouble’s quickfix after Xcodebuild failures; close it on success
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
    { "<leader>X", "<cmd>XcodebuildPicker<CR>", desc = "Show Xcodebuild Actions" },
    { "<leader>xf", "<cmd>XcodebuildProjectManager<CR>", desc = "Show Project Manager Actions" },

    { "<leader>xb", "<cmd>XcodebuildBuild<CR>", desc = "Build Project" },
    { "<leader>xB", "<cmd>XcodebuildBuildForTesting<CR>", desc = "Build For Testing" },
    { "<leader>xr", "<cmd>XcodebuildBuildRun<CR>", desc = "Build & Run Project" },

    { "<leader>xt", "<cmd>XcodebuildTest<CR>", desc = "Run Tests" },
    {
      "<leader>xt",
      "<cmd>XcodebuildTestSelected<CR>",
      mode = "v",
      desc = "Run Selected Tests",
    },
    { "<leader>xT", "<cmd>XcodebuildTestClass<CR>", desc = "Run Current Test Class" },
    { "<leader>x.", "<cmd>XcodebuildTestRepeat<CR>", desc = "Repeat Last Test Run" },

    { "<leader>xl", "<cmd>XcodebuildToggleLogs<CR>", desc = "Toggle Xcodebuild Logs" },
    { "<leader>xc", "<cmd>XcodebuildToggleCodeCoverage<CR>", desc = "Toggle Code Coverage" },
    { "<leader>xC", "<cmd>XcodebuildShowCodeCoverageReport<CR>", desc = "Show Code Coverage Report" },
    { "<leader>xe", "<cmd>XcodebuildTestExplorerToggle<CR>", desc = "Toggle Test Explorer" },
    { "<leader>xs", "<cmd>XcodebuildFailingSnapshots<CR>", desc = "Show Failing Snapshots" },

    { "<leader>xp", "<cmd>XcodebuildPreviewGenerateAndShow<CR>", desc = "Generate Preview" },
    { "<leader>x<CR>", "<cmd>XcodebuildPreviewToggle<CR>", desc = "Toggle Preview" },

    { "<leader>xd", "<cmd>XcodebuildSelectDevice<CR>", desc = "Select Device" },
    { "<leader>xq", "<cmd>Telescope quickfix<CR>", desc = "Show QuickFix List" },

    { "<leader>xx", "<cmd>XcodebuildQuickfixLine<CR>", desc = "Quickfix Line" },
    { "<leader>xa", "<cmd>XcodebuildCodeActions<CR>", desc = "Show Code Actions" },
  },
  config = function()
    require("xcodebuild").setup({
      -- put some options here or leave it empty to use default settings
    })
  end,
}
