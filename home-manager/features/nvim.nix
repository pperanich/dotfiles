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
  ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
    ];
  };
}
