return {
  -- "nvim-treesitter/nvim-treesitter",
  "rayliwell/nvim-treesitter",
  dependencies = { "nvim-treesitter/playground" },
  opts = function(_, opts)
    opts.playground = {
      enable = true,
      disable = {},
      updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
      persist_queries = false, -- Whether the query persists across vim sessions
      keybindings = {
        toggle_query_editor = "o",
        toggle_hl_groups = "i",
        toggle_injected_languages = "t",
        toggle_anonymous_nodes = "a",
        toggle_language_display = "I",
        focus_language = "f",
        unfocus_language = "F",
        update = "R",
        goto_node = "<cr>",
        show_help = "?",
      },
    }
    vim.list_extend(opts.ensure_installed, {
      "rstml",
    })
    opts.sync_install = false
    opts.highlight = { enable = true }
    opts.indent = { enable = true }
  end,
  -- ensure_installed = {},
  -- sync_install = false,
  -- highlight = { enable = true },
  -- indent = { enable = true },
  build = ":TSUpdate",
}
