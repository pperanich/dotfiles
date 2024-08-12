local obsidian_ws = "~/Library/CloudStorage/Box-Box/Obsidian/obsidian-vault/"
if vim.fn.isdirectory(obsidian_ws) then
  return {
    "epwalsh/obsidian.nvim",
    version = "*", -- recommended, use latest release instead of latest commit
    lazy = true,
    ft = "markdown",
    -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
    -- event = {
    --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
    --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
    --   -- refer to `:h file-pattern` for more examples
    --   "BufReadPre path/to/my-vault/*.md",
    --   "BufNewFile path/to/my-vault/*.md",
    -- },
    dependencies = {
      -- Required.
      "nvim-lua/plenary.nvim",

      -- see below for full list of optional dependencies 👇
    },
    keys = {
      {
        "<leader>oo",
        string.format(":cd %s", obsidian_ws),
        mode = { "n" },
        desc = "navigate to vault",
      },
      {
        "<leader>on",
        ":ObsidianTemplate note<cr> :lua vim.cmd([[1,/^\\S/s/^\\n\\{1,}//]])<cr>",
        mode = { "n" },
        desc = "convert note to template and remove leading white space",
      },
      {
        "<leader>of",
        ":s/\\(# \\)[^_]*_/\\1/ | s/-/ /g<cr>",
        mode = { "n" },
        desc = "strip date from note title and replace dashes with spaces",
      },
      {
        "<leader>os",
        string.format(':Telescope find_files path_display={"tail"} search_dirs=%s<cr>', obsidian_ws),
        mode = { "n" },
        desc = "search for files in full vault",
      },
      {
        "<leader>oz",
        string.format(':Telescope live_grep path_display={"tail"} search_dirs=%s<cr>', obsidian_ws),
        mode = { "n" },
        desc = "search for files in full vault",
      },
      {
        "<leader>odd",
        ":!rm '%:p'<cr>:bd<cr>",
        mode = { "n" },
        desc = "delete file in current buffer",
      },
    },
    opts = {
      workspaces = {
        {
          name = "work",
          path = "~/Library/CloudStorage/Box-Box/Obsidian/",
        },
      },
      notes_subdir = "inbox",
      new_notes_location = "notes_subdir",

      disable_frontmatter = true,
      templates = {
        subdir = "templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M:%S",
      },

      -- name new notes starting the ISO datetime and ending with note name
      -- put them in the inbox subdir
      -- note_id_func = function(title)
      --   local suffix = ""
      --   -- get current ISO datetime with -5 hour offset from UTC for EST
      --   local current_datetime = os.date("!%Y-%m-%d-%H%M%S", os.time() - 5*3600)
      --   if title ~= nil then
      --     suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
      --   else
      --     for _ = 1, 4 do
      --       suffix = suffix .. string.char(math.random(65, 90))
      --     end
      --   end
      --   return current_datetime .. "_" .. suffix
      -- end,

      -- key mappings, below are the defaults
      mappings = {
        -- overrides the 'gf' mapping to work on markdown/wiki links within your vault
        ["gf"] = {
          action = function()
            return require("obsidian").util.gf_passthrough()
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
        -- toggle check-boxes
        -- ["<leader>ch"] = {
        --   action = function()
        --     return require("obsidian").util.toggle_checkbox()
        --   end,
        --   opts = { buffer = true },
        -- },
      },
      completion = {
        nvim_cmp = true,
        min_chars = 2,
      },
      ui = {
        -- Disable some things below here because I set these manually for all Markdown files using treesitter
        checkboxes = {},
        bullets = {},
      },
      callbacks = {
        -- Runs at the end of `require("obsidian").setup()`.
        ---@param client obsidian.Client
        post_setup = function(client)
          -- vim.api.nvim_create_user_command("ObsidianRefreshTags", function()
          --   tagstore = client:find_notes()
          -- end, {
          --   desc = "Find Obsidian Notes",
          -- })
        end,
      },
    },
  }
else
  return {}
end
