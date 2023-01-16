{ inputs, lib, pkgs, config, outputs, ... }:
{
  imports = [
    ../features/cli.nix
    ../features/nvim.nix
    ../features/emacs.nix
    ../features/desktop.nix
    ../features/tex.nix
    ../features/zotero.nix
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  programs = {
    home-manager.enable = true;
    pandoc.enable = true;
    git = {
      enable = true;
      extraConfig = {
        protocol.file = { allow = "always"; };
      };
    };

    # zsh.enable = true;
  };

  xdg.enable = true;

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      warn-dirty = false;
    };
  };

  home = {
    username = lib.mkDefault "peranpl1";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "22.05";
  };
}
