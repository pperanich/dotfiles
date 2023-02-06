{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;

  emacs = if pkgs.stdenv.hostPlatform.isDarwin then
  pkgs.emacsMacport.override { withMacport = true; withSQLite3 = true; withWebP = true; withImageMagick = true; }
  # (pkgs.emacsMacport.overrideAttrs (prev: rec {
  #     patches = prev.patches ++ [
  #         (pkgs.fetchpatch {
  #           name = "No Titlebar";
  #           url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-28/no-titlebar.patch";
  #           sha256 = "sha256-NI2Xpy/BJHk3dqZgGchA1FO/4shbybQcVl4rbGEg2i8=";
  #         })
  #       ];
  #   })).override{ withMacport = true; withSQLite3 = true; withWebP = true; withImageMagick = true; }
  else
  pkgs.emacsGit.override { withImageMagick = true; };
in
{
  home.packages = with pkgs; [
    nodePackages.pyright
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    epdfview
  ];

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
