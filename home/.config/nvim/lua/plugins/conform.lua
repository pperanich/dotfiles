return {
  {
    "stevearc/conform.nvim",
    opts = {
      -- Define formatters, including our modified prettier
      formatters = {
        -- Modify the main prettier definition
        prettier = {
          -- Instead of a static list, use a function for prepend_args
          prepend_args = function(_, ctx)
            local args_to_prepend = {} -- Default to empty args

            -- Check if the filename in the context ends with .aip
            if ctx.filename and ctx.filename:match("%.aip$") then
              -- If it's an .aip file, set the specific flag
              args_to_prepend = { "--parser=markdown" }

              -- *** Add the notification here ***
              -- We use vim.fs.basename to just show the filename, not the full path
              -- local filename_only = ctx.filename and vim.fs.basename(ctx.filename) or "unknown file"
              -- vim.notify(
              --   string.format("Conform: Detected .aip file (%s), using prettier with --parser=markdown", filename_only),
              --   vim.log.levels.INFO, -- Specify the log level (INFO is good for confirmation)
              --   { title = "Conform Formatter" } -- Optional title for the notification window
              -- )
              -- Optional: Add an else block if you want confirmation for non-aip files too
              -- else
              --   vim.notify(
              --     string.format("Conform: Using default prettier for %s", vim.fs.basename(ctx.filename)),
              --     vim.log.levels.INFO,
              --     { title = "Conform Formatter" }
              --   )
            end

            -- Return the determined arguments
            return args_to_prepend
          end,
        },
      },
    },
  },
}
