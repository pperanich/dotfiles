return {
  "stevearc/oil.nvim",
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    view_options = {
      show_hidden = true,
    },
  },

  -- Optional dependencies
  dependencies = { { "nvim-mini/mini.icons", opts = {} } },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
  keys = {
    { "<leader>fo", "<cmd>Oil<cr>", desc = "Open parent directory" },
    {
      "gy",
      function()
        require("oil.actions").copy_entry_path.callback()
        vim.fn.setreg("+", vim.fn.getreg(vim.v.register))
      end,
      desc = "Copy filepath to system clipboard",
      ft = "oil",
    },
  },
}
