return {
  "jackMort/ChatGPT.nvim",
  event = "VeryLazy",
  config = function()
    require("chatgpt").setup()
    local wk = require("which-key")
    wk.add({
      { "<leader>cc", group = "ChatGPT" },
      { "<leader>ccc", "<cmd>ChatGPT<CR>", desc = "ChatGPT" },
      {
        mode = { "n", "v" },
        { "<leader>cca", "<cmd>ChatGPTRun add_tests<CR>", desc = "Add Tests" },
        { "<leader>ccd", "<cmd>ChatGPTRun docstring<CR>", desc = "Docstring" },
        { "<leader>cce", "<cmd>ChatGPTEditWithInstruction<CR>", desc = "Edit with instruction" },
        { "<leader>ccf", "<cmd>ChatGPTRun fix_bugs<CR>", desc = "Fix Bugs" },
        { "<leader>ccg", "<cmd>ChatGPTRun grammar_correction<CR>", desc = "Grammar Correction" },
        { "<leader>cck", "<cmd>ChatGPTRun keywords<CR>", desc = "Keywords" },
        { "<leader>ccl", "<cmd>ChatGPTRun code_readability_analysis<CR>", desc = "Code Readability Analysis" },
        { "<leader>cco", "<cmd>ChatGPTRun optimize_code<CR>", desc = "Optimize Code" },
        { "<leader>ccr", "<cmd>ChatGPTRun roxygen_edit<CR>", desc = "Roxygen Edit" },
        { "<leader>ccs", "<cmd>ChatGPTRun summarize<CR>", desc = "Summarize" },
        { "<leader>cct", "<cmd>ChatGPTRun translate<CR>", desc = "Translate" },
        { "<leader>ccx", "<cmd>ChatGPTRun explain_code<CR>", desc = "Explain Code" },
      },
    })
  end,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
}
