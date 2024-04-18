{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.lib.meta) mkMutableSymlink;
in
{
  home.sessionVariables = { EDITOR = "nvim"; };
  home.packages = with pkgs; [
    fzf
    pkg-config
    mktemp
    # llvmPackages_16.clang-unwrapped
  ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    extraConfig = ''
      lua <<EOF
        -- require("kickstart")
        -- bootstrap lazy.nvim, LazyVim and your plugins
        require("config.lazy")
      EOF
    '';

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
    ];
  };

  xdg.configFile."nvim/lua/".source = mkMutableSymlink "nvim/lua/";
  # xdg.configFile."nvim/after/".source = mkMutableSymlink "nvim/after/";
}
