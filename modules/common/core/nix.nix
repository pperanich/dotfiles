# Nix-specific configuration
{ inputs, lib, outputs, config, ... }:

let
  cfg = config.modules.core;
in
{
  config = lib.mkIf cfg.enable {
    nix = {
      settings = {
        trusted-users = [ "root" "@wheel" ];
        auto-optimise-store = lib.mkDefault true;
        experimental-features = [ "nix-command" "flakes" ];
        warn-dirty = false;
        system-features = [ "kvm" "big-parallel" "nixos-test" ];
        flake-registry = ""; # Disable global flake registry
      };
      gc = {
        automatic = true;
        dates = "weekly";
        # Delete older generations too
        options = "--delete-older-than 2d";
      };

      # Add each flake input as a registry
      # To make nix3 commands consistent with the flake
      registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

      # Add nixpkgs input to NIX_PATH
      # This lets nix2 commands still use <nixpkgs>
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    };

    nixpkgs = {
      overlays = builtins.attrValues outputs.overlays;
      config = {
        permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
        allowUnfree = true;
        allowUnfreePredicate = _: true;
      };
    };
  };
}
