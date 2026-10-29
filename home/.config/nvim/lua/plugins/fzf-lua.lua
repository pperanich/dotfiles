return {
  "ibhagwan/fzf-lua",
  init = function()
    -- fzf-lua's own socket ($run/fzf-lua.<epoch>) overflows macOS's 104-byte
    -- sun_path under a nix-shell TMPDIR; reuse nvim's shorter startup socket.
    local run = vim.fn.stdpath("run") .. "/fzf-lua." .. os.time()
    if #run > 104 and vim.v.servername ~= "" then
      vim.g.fzf_lua_server = vim.v.servername
    end
  end,
}
