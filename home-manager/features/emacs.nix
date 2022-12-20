{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
  inherit (pkgs) fetchFromGitHub;

  # emacs = inputs.emacs-overlay.packages.${pkgs.system}.emacsGit.overrideAttrs (attrs: {
  my-emacs = pkgs.emacs.overrideAttrs (attrs: {
    # patches = (attrs.patches or [ ]) ++ [
    #   ./patches/poll.patch
    # ];
    # configureFlags = attrs.configureFlags ++ ["--with-poll"];
    macportVersion = "emacs-28.2-mac-9.1";
  });

in
{
  programs.emacs = {
    enable = true;
    package = my-emacs.override { withMacport = true; withSQLite3 = true; withWebP = true; withImageMagick = true; };
    # package = emacs.override { withMacport = true; };
  };

  xdg.configFile."emacs".source = fetchFromGitHub 
  {
    owner = "plexus"; repo = "chemacs2";
    rev = "fb6301d1563c6cf88c8aac51ff8bcd4e06276139";
    sha256 = "sha256-cYIC5P0t7YJxfAF8g7Q2Stfz8+wrqXLonrfsEhotVY0=";
  };
  xdg.configFile."chemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/chemacs/";

  # xdg.configFile."emacs-spacemacs".source = fetchFromGitHub 
  # {
  #   owner = "syl20bnr";
  #   repo = "spacemacs";
  #   rev = "b74da79dbbd8573ab4f43721c74014d6f54d8bd0";
  #   sha256 = "sha256-ysydhBD1FqA22E7wejcfaElTL/BjC6Obi9LA87knmVI=";
  # };
  xdg.configFile."spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/spacemacs/";
  xdg.configFile."emacs-spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-spacemacs/";

  # xdg.configFile."emacs-doom".source = fetchFromGitHub 
  # {
  #   owner = "doomemacs";
  #   repo = "doomemacs";
  #   rev = "d5ccac5d71c819035fa251f01d023b3f94b4fba4";
  #   sha256 = "sha256-7AzL08qo5WLeJo10lnF2b7g6FdWnExVYS8yipNyAMMM=";
  # };
  xdg.configFile."doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/doom/";
  xdg.configFile."emacs-doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-doom/";
}
