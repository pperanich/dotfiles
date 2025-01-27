# Emacs editor configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.development.editors;
  inherit (config.home) homeDirectory;

  # Fetch the repositories
  chemacs2 = pkgs.fetchFromGitHub {
    owner = "plexus";
    repo = "chemacs2";
    rev = "c2d700b784c793cc82131ef86323801b8d6e67bb"; # Replace with specific commit/tag
    sha256 = "sha256-/WtacZPr45lurS0hv+W8UGzsXY3RujkU5oGGGqjqG0Q=";
  };

  doomemacs = pkgs.fetchFromGitHub {
    owner = "doomemacs";
    repo = "doomemacs";
    rev = "2bc052425ca45a41532be0648ebd976d1bd2e6c1"; # Replace with specific commit/tag
    sha256 = "sha256-i0GVHWoIqDcFB9JmEdd9T+qxrEx3ckBlPfTD/yLoNyg=";
  };

  spacemacs = pkgs.fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "11aaddf3ad7e5e3dd3b494d56221efe7b882fd72"; # Replace with specific commit/tag
    sha256 = "sha256-uozaV6igLIufvFzPrbt9En1VStDZDkSRRyxH62elK+8=";
  };

  emacs =
    if pkgs.stdenv.hostPlatform.isDarwin
    then
      (pkgs.emacs-git.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            # Fix OS window role (needed for window managers like yabai)
            (pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-28/fix-window-role.patch";
              sha256 = "sha256-+z/KfsBm1lvZTZNiMbxzXQGRTjkCFO4QPlEK35upjsE=";
            })
            # Use poll instead of select to get file descriptors
            # (pkgs.fetchpatch {
            #   url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-31/poll.patch";
            #   sha256 = "sha256-HPuHrsKq17ko8xP8My+IYcJV+PKio4jK41qID6QFXFs=";
            # })
            # Enable rounded window with no decoration
            (pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-31/round-undecorated-frame.patch";
              sha256 = "sha256-/SX8rF4GMA7bobfQ4/F9BTSEigeOd9jgN0jvQ1M0MSs=";
            })
            # Make Emacs aware of OS-level light/dark mode
            (pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-30/system-appearance.patch";
              sha256 = "sha256-3QLq91AQ6E921/W9nfDjdOUWR8YVsqBAT/W9c1woqAw=";
            })
          ];
      }))
      .override
      {
        withSQLite3 = true;
        withWebP = true;
        withImageMagick = true;
        withTreeSitter = true;
      }
    else
      pkgs.emacs-git.override {
        withImageMagick = true;
        withTreeSitter = true;
      };
in {
  config = lib.mkIf (cfg.enable && cfg.emacs.enable) {
    programs.emacs = {
      enable = true;
      package = emacs;
      extraPackages = epkgs: [epkgs.treesit-grammars.with-all-grammars epkgs.vterm];
    };

    home = {
      sessionPath = ["${homeDirectory}/.config/emacs-doom/bin"];
      sessionVariables = {DOOMDIR = "${homeDirectory}/.config/doom-literate";};
      packages = with pkgs;
        [
          pyright
          jansson
          djvulibre
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          qpdfview
          libvterm
        ];
      file = {
        ".config/emacs".source = chemacs2;
        ".config/emacs-doom".source = doomemacs;
        ".config/emacs-spacemacs".source = spacemacs;
      };
    };
  };
}
