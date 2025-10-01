# Library functions for dotfiles management
{lib, ...}: {
  # Use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;

  # Create system-specific package set with common configuration
  mkPkgs = {
    nixpkgs,
    system,
    config ? {},
  }:
    import nixpkgs {
      inherit system;
      config =
        {
          allowUnfree = true;
          allowBroken = true;
          permittedInsecurePackages = [
            "openssl-1.1.1w"
          ];
        }
        // config;
    };

  # Create package sets for all supported systems
  mkPkgsFor = {nixpkgs}: let
    mkPkgs = {
      system,
      config ? {},
    }:
      import nixpkgs {
        inherit system;
        config =
          {
            allowUnfree = true;
            allowBroken = true;
            permittedInsecurePackages = [
              "openssl-1.1.1w"
            ];
          }
          // config;
      };
  in
    lib.genAttrs
    ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
    (system: mkPkgs {inherit system;});

  # Get all home-manager directories that contain a default.nix file
  getHomeDirs = homePath:
    lib.attrNames (
      lib.attrsets.filterAttrs (
        name: type:
          type == "directory" && builtins.pathExists (homePath + "/${name}/default.nix")
      ) (builtins.readDir homePath)
    );

  # Generate Home Manager configurations from home-profiles directory
  mkHomeConfigurations = {
    homePath ? ../home-profiles,
    inputs,
    outputs,
    lib ? lib,
    home-manager,
    pkgsFor,
    extraSpecialArgs ? {},
    # Additional users to create for generic configuration
    additionalUsers ? [],
  }: let
    homeDirs = lib.my.getHomeDirs homePath;

    # Regular user configurations (not generic)
    userConfigs =
      lib.genAttrs
      (builtins.filter (name: name != "generic") homeDirs)
      (username:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.x86_64-linux;
          modules = [
            (homePath + "/${username}")
          ];
          extraSpecialArgs =
            {
              inherit inputs outputs;
              lib = lib.extend (_: _: home-manager.lib);
            }
            // extraSpecialArgs;
        });

    # Generic configurations for additional users
    genericConfigs =
      if builtins.elem "generic" homeDirs
      then
        lib.genAttrs additionalUsers (
          username:
            home-manager.lib.homeManagerConfiguration {
              pkgs = pkgsFor.x86_64-linux;
              modules = [
                (homePath + "/generic")
                {
                  home = {
                    inherit username;
                    homeDirectory = "/home/${username}";
                  };
                }
              ];
              extraSpecialArgs =
                {
                  inherit inputs outputs;
                  lib = lib.extend (_: _: home-manager.lib);
                }
                // extraSpecialArgs;
            }
        )
      else {};
  in
    userConfigs // genericConfigs;
}
