# Neovim editor configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.development.editors;
in {
  config = lib.mkIf (cfg.enable && cfg.neovim.enable) {
    home.sessionVariables = {EDITOR = "nvim";};
    home.packages = with pkgs; [
      fzf
      pkg-config
      mktemp
    ];

    programs.neovim = {
      enable = true;
      package = pkgs.neovim;

      plugins = with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars
        nvim-treesitter-context
      ];
    };
  };
}
