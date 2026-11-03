return {
  "folke/snacks.nvim",
  opts = {
    -- Rex answers the kitty graphics protocol, but it does not render Unicode
    -- placeholders (U=1) yet, and snacks only detects kitty, ghostty and
    -- wezterm by name. Force the protocol so the fallback placement path runs.
    image = { enabled = true, force = true },
  },
  init = function()
    -- The section only lists conversion tools this machine does not have, so
    -- drop it from :checkhealth rather than leave it red.
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        if Snacks and Snacks.image and Snacks.image.meta then
          Snacks.image.meta.health = false
        end
      end,
    })
  end,
}
