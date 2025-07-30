return {
  {
    "rayliwell/tree-sitter-rstml",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    build = ":TSUpdate",
    config = function()
      require("tree-sitter-rstml").setup()
    end,
  },
  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   opts = function(_, opts)
  --     -- add tsx and treesitter
  --     vim.list_extend(opts.ensure_installed, {
  --       "rust_with_rstml",
  --     })
  --   end,
  -- },
}
