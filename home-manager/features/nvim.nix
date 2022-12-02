{ config, pkgs, lib, inputs, ... }:
let
  neovim-overlay = inputs.neovim-nightly-overlay.packages.${pkgs.system};
  parserDir = pkgs.tree-sitter.withPlugins (tree-sitter-grammars-fn);
  tree-sitter-grammars-fn = p: with p; nvim-treesitter.withAllGrammars;
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.sessionVariables.EDITOR = "nvim";

  programs.neovim = {
    enable = true;
    package = neovim-overlay.neovim;
    extraConfig = ''
      lua <<EOF
        require("kickstart")
      EOF
    '';

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
    ];
  };

  xdg.configFile."nvim/lua/".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/nvim/lua/";
}
