{ inputs, lib, pkgs, config, outputs, ... }:
{
  imports = [
    ../features/cli.nix
    ../features/nvim.nix
    ../features/desktop.nix
    ../features/tex.nix
    ../features/zotero.nix
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  programs = {
    home-manager.enable = true;
    git.enable = true;
    pandoc.enable = true;
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
    # activation = lib.mkIf pkgs.stdenv.isDarwin {
    #   copyApplications = let
    #     apps = pkgs.buildEnv {
    #       name = "home-manager-applications";
    #       paths = config.home.packages;
    #       pathsToLink = "/Applications";
    #     };
    #   in lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    #     baseDir="$HOME/Applications/Home Manager Apps"
    #     if [ -d "$baseDir" ]; then
    #       rm -rf "$baseDir"
    #       rmdir "$baseDir"
    #     fi
    #     mkdir -p "$baseDir"
    #     for appFile in ${apps}/Applications/*; do
    #       target="$baseDir/$(basename "$appFile")"
    #       $DRY_RUN_CMD cp -av ''${VERBOSE_ARG:+-v} -fHRL "$appFile" "$baseDir"
    #       $DRY_RUN_CMD chmod ''${VERBOSE_ARG:+-v} -R +w "$target"
    #     done
    #   '';
    #   };
    stateVersion = lib.mkDefault "22.05";
  };
}
