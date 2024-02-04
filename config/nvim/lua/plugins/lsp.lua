return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      format = { timeout_ms = 30000 },
      servers = {
        tailwindcss = {
          filetypes_include = { "rust" },
          init_options = {
            userLanguages = {
              rust = "html",
            }
          },
          on_attach = function(_, bufnr)
            require("tailwindcss-colors").buf_attach(bufnr)
          end
        }
      }
    }
  },
  {
    "themaxmarchuk/tailwindcss-colors.nvim",
  },
}
