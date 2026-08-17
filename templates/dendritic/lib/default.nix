# Repo-local helpers, exposed as lib.my.* (see modules/flake-parts/nixpkgs.nix)
{ lib, ... }:
rec {
  # Path relative to the flake root, e.g. lib.my.relativeToRoot "home-profiles/example"
  relativeToRoot = lib.path.append ../.;

  # Single source of truth for authorized SSH keys
  sshKeys = {
    # example = "ssh-ed25519 AAAAC3Nz... example@host";
  };

  # Directories under `homePath` that contain a default.nix
  getHomeDirs =
    homePath:
    lib.attrNames (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (homePath + "/${name}/default.nix")
      ) (builtins.readDir homePath)
    );

  # One standalone home-manager configuration per directory in home-profiles/
  mkHomeConfigurations =
    {
      homePath,
      inputs,
      outputs,
      home-manager,
      pkgs,
      extraSpecialArgs ? { },
    }:
    lib.genAttrs (getHomeDirs homePath) (
      username:
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          (homePath + "/${username}")
          { home.username = lib.mkDefault username; }
        ];
        extraSpecialArgs = {
          inherit inputs outputs;
          inherit (outputs.modules) homeManager;
        }
        // extraSpecialArgs;
      }
    );
}
