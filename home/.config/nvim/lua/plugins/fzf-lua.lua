return {
  "ibhagwan/fzf-lua",
  init = function()
    -- fzf-lua starts its RPC socket at $run/fzf-lua.<epoch>. Under a nested
    -- nix-shell TMPDIR that path blows past macOS's sun_path limit and
    -- serverstart() fails with EINVAL, so requiring fzf-lua raises E5108 and
    -- every picker is dead. $run is also not always writable. Start a socket
    -- at a short, fixed path instead and hand it to fzf-lua.
    local ok, server = pcall(vim.fn.serverstart, ("/tmp/nvim-fzf-lua.%d.%d"):format(vim.fn.getpid(), os.time()))
    if ok and server ~= "" then
      vim.g.fzf_lua_server = server
    elseif vim.v.servername ~= "" then
      vim.g.fzf_lua_server = vim.v.servername
    end
  end,
}
