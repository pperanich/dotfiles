{ config, pkgs, lib, inputs, ... }:
let
  emacs-overlay = inputs.emacs-overlay.packages.${pkgs.system};
  parserDir = pkgs.tree-sitter.withPlugins (tree-sitter-grammars-fn);
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  programs.emacs = {
    enable = true;
    package = emacs-overlay.emacs;
  };

  xdg.configFile."emacs".source = fetchFromGithub 
  {
    owner = "plexus";
    repo = "chemacs2";
    rev = "fb6301d1563c6cf88c8aac51ff8bcd4e06276139";
    sha256 = "sha256-cYIC5P0t7YJxfAF8g7Q2Stfz8+wrqXLonrfsEhotVY0=";
  };
  xdg.configFile."chemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/chemacs/";

  xdg.configFile."emacs-spacemacs".source = fetchFromGithub 
  {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "b74da79dbbd8573ab4f43721c74014d6f54d8bd0";
    sha256 = "sha256-ysydhBD1FqA22E7wejcfaElTL/BjC6Obi9LA87knmVI=";
  };
  xdg.configFile."spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/spacemacs/";

  xdg.configFile."emacs-doom".source = fetchFromGithub 
  {
    owner = "doomemacs";
    repo = "doomemacs";
    rev = "d5ccac5d71c819035fa251f01d023b3f94b4fba4";
    sha256 = "sha256-7AzL08qo5WLeJo10lnF2b7g6FdWnExVYS8yipNyAMMM=";
  };
  xdg.configFile."doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/doom/";
}
