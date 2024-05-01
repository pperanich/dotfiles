return {
  -- add gruvbox
  { "ishan9299/modus-theme-vim" },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "modus-vivendi",
    },
  },
}
