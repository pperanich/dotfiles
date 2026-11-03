return {
  "ibhagwan/fzf-lua",
  init = function()
    -- fzf-lua starts its own RPC socket at $run/fzf-lua.<epoch>, which
    -- overflows macOS's 104-byte sun_path under a nix-shell TMPDIR and makes
    -- serverstart() fail with EINVAL, leaving every picker silently dead.
    -- nvim already runs a server, so hand its socket to fzf-lua whenever one
    -- exists instead of betting on the path staying short enough.
    if vim.v.servername ~= "" then
      vim.g.fzf_lua_server = vim.v.servername
    end
  end,
}
