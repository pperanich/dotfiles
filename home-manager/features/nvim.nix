{ pkgs, ... }:
{
  home.sessionVariables = { EDITOR = "nvim"; };
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
}
