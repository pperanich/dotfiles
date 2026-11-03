return {
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
      -- Required for ask() and select()
      ---@module 'snacks'
      { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        provider = {
          enabled = "snacks",
        },
      }

      -- Required for opts.events.reload
      vim.o.autoread = true

      vim.keymap.set({ "n", "x" }, "<leader>oa", function()
        require("opencode").ask("@this: ", { submit = true })
      end, { desc = "Ask opencode" })

      vim.keymap.set({ "n", "x" }, "<leader>os", function()
        require("opencode").select()
      end, { desc = "Select opencode action" })

      vim.keymap.set({ "n", "t" }, "<leader>oo", function()
        require("opencode").toggle()
      end, { desc = "Toggle opencode" })

      vim.keymap.set({ "n", "x" }, "<leader>op", function()
        return require("opencode").operator("@this ")
      end, { desc = "Add range to opencode", expr = true })

      vim.keymap.set("n", "<leader>oP", function()
        return require("opencode").operator("@this ") .. "_"
      end, { desc = "Add line to opencode", expr = true })

      vim.keymap.set("n", "<leader>ou", function()
        require("opencode").command("session.half.page.up")
      end, { desc = "Scroll opencode up" })

      vim.keymap.set("n", "<leader>od", function()
        require("opencode").command("session.half.page.down")
      end, { desc = "Scroll opencode down" })
    end,
  },
}
