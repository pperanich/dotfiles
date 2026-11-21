# Library functions for dotfiles management
{ lib, ... }:
let
  adminKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBo5QIQYUJUadtK19vPdCROhdFbB63XX0XYfonzTqiuA pperanich@pp-ml1";
in
{
  # Use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;

  # SSH public keys for interactive OS login (`wheel` / admin workstations only;
  # never add WSL or untrusted VM keys here).
  # Flat attrset shape (`builtins.attrValues lib.my.sshKeys`) is part of the
  # downstream `~/nix-private` upstream contract.
  sshKeys = {
    pp-ml1 = adminKey;
  };

  # Keys that log in as root, which is how deploy-rs activates (decision 0008).
  # The admin workstation only: a key added to sshKeys must not land here.
  deploySshKeys = [ adminKey ];

  # Host public keys pinned in every host's known_hosts (`programs.ssh.knownHosts`).
  sshHostKeys = import ./ssh-host-keys.nix;

  mkKnownHosts = lib.mapAttrs (
    host: publicKey: {
      hostNames = [
        host
        "${host}.home.arpa"
        "${host}.pp-ts"
      ]
      # Services that answer SSH on a host's key under another name (Gitea's git@ remote).
      ++ ({ pp-router1 = [ "gitea.prestonperanich.com" ]; }.${host} or [ ]);
      inherit publicKey;
    }
  );

  # Homelab-wide constants — single source of truth for the public zone
  homelab = rec {
    publicDomain = "prestonperanich.com";
    mkSub = sub: "${sub}.${publicDomain}";
    rexWorker = {
      address = "100.64.0.4"; # pp-wsl1 on Headscale
      port = 7297;
      user = "hermes-worker";
    };
  };

  # Get all home-manager directories that contain a default.nix file
  getHomeDirs =
    homePath:
    lib.attrNames (
      lib.attrsets.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (homePath + "/${name}/default.nix")
      ) (builtins.readDir homePath)
    );

  # Generate Home Manager configurations from home-profiles directory
  mkHomeConfigurations =
    {
      homePath ? ../home-profiles,
      inputs,
      outputs,
      lib ? lib,
      home-manager,
      pkgs,
      extraSpecialArgs ? { },
      # Additional users to create for generic configuration
      additionalUsers ? [ ],
    }:
    let
      homeDirs = lib.my.getHomeDirs homePath;

      # Regular user configurations (not generic)
      userConfigs = lib.genAttrs (builtins.filter (name: name != "generic") homeDirs) (
        username:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            (homePath + "/${username}")
          ];
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit (outputs.modules) homeManager;
            lib = lib.extend (_: _: home-manager.lib);
          }
          // extraSpecialArgs;
        }
      );

      # Generic configurations for additional users
      genericConfigs =
        if builtins.elem "generic" homeDirs then
          lib.genAttrs additionalUsers (
            username:
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                (homePath + "/generic")
                {
                  home = {
                    inherit username;
                    homeDirectory = "/home/${username}";
                  };
                }
              ];
              extraSpecialArgs = {
                inherit inputs outputs;
                inherit (outputs.modules) homeManager;
                lib = lib.extend (_: _: home-manager.lib);
              }
              // extraSpecialArgs;
            }
          )
        else
          { };
    in
    userConfigs // genericConfigs;
}
