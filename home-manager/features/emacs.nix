{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;

  emacs = if pkgs.stdenv.hostPlatform.isDarwin then
    pkgs.emacsMacport.override { withMacport = true; withSQLite3 = true; withWebP = true; withImageMagick = true; }
    else
    inputs.emacs-overlay.packages.${pkgs.system}.emacsGit.override { withImageMagick = true; };
in
{
  programs.emacs = {
  enable = true;
  package = emacs;
  };

  xdg.configFile."emacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-chemacs/";
  xdg.configFile."chemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/chemacs/";
  xdg.configFile."emacs-spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-spacemacs/";
  xdg.configFile."spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/spacemacs/";
  xdg.configFile."emacs-doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-doom/";
  xdg.configFile."doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/doom/";
  xdg.configFile."yasnippet".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/yasnippet/";
}
