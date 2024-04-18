{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;

  emacs =
    if pkgs.stdenv.hostPlatform.isDarwin then
      (pkgs.emacs-git.overrideAttrs (old: {
        patches =
          (old.patches or [ ])
          ++ [
            # Fix OS window role (needed for window managers like yabai)
            (pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-28/fix-window-role.patch";
              sha256 = "sha256-+z/KfsBm1lvZTZNiMbxzXQGRTjkCFO4QPlEK35upjsE=";
            })
            # Use poll instead of select to get file descriptors
            (pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-29/poll.patch";
              sha256 = "sha256-jN9MlD8/ZrnLuP2/HUXXEVVd6A+aRZNYFdZF8ReJGfY=";
            })
            # Enable rounded window with no decoration
            (pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-30/round-undecorated-frame.patch";
              sha256 = "sha256-uYIxNTyfbprx5mCqMNFVrBcLeo+8e21qmBE3lpcnd+4=";
            })
            # Make Emacs aware of OS-level light/dark mode
            (pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-28/system-appearance.patch";
              sha256 = "sha256-oM6fXdXCWVcBnNrzXmF0ZMdp8j0pzkLE66WteeCutv8=";
            })
          ];
      })).override
        { withSQLite3 = true; withWebP = true; withImageMagick = true; withTreeSitter = true; }
    else
      pkgs.emacs-git.override { withImageMagick = true; withTreeSitter = true; };
  emacs-with-pkgs = with pkgs; ((emacsPackagesFor emacs).emacsWithPackages (epkgs: with epkgs; [
    treesit-grammars.with-all-grammars
  ]));
in
{

  programs.emacs = {
    enable = true;
    package = emacs-with-pkgs;
  };

  xdg = {
    configFile = {
      "emacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-chemacs/";
      "chemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/chemacs/";
      "emacs-spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-spacemacs/";
      "spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/spacemacs/";
      "emacs-doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-doom/";
      # "doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/doom/";
      "doom-literate".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/doom-literate/";
      "yasnippet".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/yasnippet/";
    };
  };

  home = {
    sessionPath = [ "${homeDirectory}/dotfiles/config/emacs-doom/bin" ];
    sessionVariables = { DOOMDIR = "${homeDirectory}/dotfiles/config/doom-literate"; };
    packages = with pkgs; [
      nodePackages.pyright
      jansson
      djvulibre
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      epdfview
      libvterm
    ];
  };
}
