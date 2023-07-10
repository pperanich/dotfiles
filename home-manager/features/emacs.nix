{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;

  emacs = if pkgs.stdenv.hostPlatform.isDarwin then
  (pkgs.emacs-git.overrideAttrs (old: {
      patches =
        (old.patches or [])
        ++ [
          # ./patches/macos-nosignal.patch
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
    })).override { withSQLite3 = true; withWebP = true; withImageMagick = true; withPgtk = true; withTreeSitter = true; }
  else
  pkgs.emacs-git.override { withImageMagick = true; withTreeSitter = true; };

  # emacs-lsp = emacs.overrideAttrs (attrs: { src = pkgs.fetchFromGitHub {
  #     owner="sebastiansturm";
  #     repo = "emacs";
  #     rev = "99186e71bff84a2fb217ef381437683d396cb811";
  #     hash = "sha256-M3i9ftk4e3HWGLT5uEG9gynTA5uUJwPSddGlZF0VmQs=";
  #   }; }).override { withSQLite3 = true; withWebP = true; withImageMagick = true; withPgtk = true; withTreeSitter = true; };
  emacs-with-pkgs = with pkgs; ((emacsPackagesFor emacs).emacsWithPackages (epkgs: [
    epkgs.tree-sitter
    epkgs.tree-sitter-langs
  ]));
in
{
  home.packages = with pkgs; [
    nodePackages.pyright
    jansson
    # tree-sitter-grammars.tree-sitter-python
    # tree-sitter.allGrammars
    # tree-sitter.withPlugins (_: allGrammars)
    # tree-sitter.withPlugins (plugins: tree-sitter.allGrammars)
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    epdfview
    libvterm
  ];

  programs.emacs = {
    enable = true;
    package = emacs-with-pkgs;
  };

  xdg.configFile."emacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-chemacs/";
  xdg.configFile."chemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/chemacs/";
  xdg.configFile."emacs-spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-spacemacs/";
  xdg.configFile."spacemacs".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/spacemacs/";
  xdg.configFile."emacs-doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/emacs-doom/";
  # xdg.configFile."doom".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/doom/";
  xdg.configFile."doom-literate".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/doom-literate/";
  xdg.configFile."yasnippet".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/yasnippet/";
}
