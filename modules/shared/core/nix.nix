# Nix-specific configuration
{
  pkgs,
  inputs,
  lib,
  outputs,
  config,
  ...
}: let
  cfg = config.my.core;
in {
  config = lib.mkIf cfg.enable {
    nix = {
      settings = {
        trusted-users = ["root" "@wheel"];
        experimental-features = ["nix-command" "flakes"];
        warn-dirty = false;
        system-features = ["kvm" "big-parallel" "nixos-test"];
        flake-registry = ""; # Disable global flake registry
      };
      optimise.automatic = true;
      # gc = {
      #   automatic = true;
      #   interval = "weekly";
      #   # Delete older generations too
      #   options = "--delete-older-than 2d";
      # };

      # Add each flake input as a registry
      # To make nix3 commands consistent with the flake
      registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

      # Add nixpkgs input to NIX_PATH
      # This lets nix2 commands still use <nixpkgs>
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    };

    nixpkgs = {
      overlays = builtins.attrValues outputs.overlays;
      config = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
        permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
        packageOverrides = _: {
          nixcasks = import inputs.nixcasks {
            inherit pkgs;
            osVersion = "sequoia";
          };
        };
      };
    };
  };
}
