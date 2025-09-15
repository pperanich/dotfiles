# FIXME(lib.my): Add some stuff from hmajid2301/dotfiles/lib/module/default.nix, as simplifies option declaration
{lib, ...}: {
  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;
  scanPaths = path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
            (_type == "directory") # include directories
            || (
              (path != "default.nix") # ignore default.nix
              && (lib.strings.hasSuffix ".nix" path) # include .nix files
            )
        ) (builtins.readDir path)
      )
    );

  # configPath = "${config.home.homeDirectory}/dotfiles/home/";
  # mkMutableSymlink = path: config.lib.file.mkOutOfStoreSymlink (config.lib.meta.configPath + path);

  # Get all host directories that contain a configuration.nix file
  getHostDirs = machinesPath:
    lib.attrNames (
      lib.attrsets.filterAttrs (
        name: type:
          type == "directory" && builtins.pathExists (machinesPath + "/${name}/configuration.nix")
      ) (builtins.readDir machinesPath)
    );

  # Get all home-manager directories that contain a default.nix file
  getHomeDirs = homePath:
    lib.attrNames (
      lib.attrsets.filterAttrs (
        name: type:
          type == "directory" && builtins.pathExists (homePath + "/${name}/default.nix")
      ) (builtins.readDir homePath)
    );

  # Check if a host configuration is for Darwin by examining the config file
  isDarwinHost = hostPath: let
    configFile = builtins.readFile (hostPath + "/configuration.nix");
  in
    builtins.match ".*darwinModules.*" configFile
    != null
    || builtins.match ".*aarch64-darwin.*" configFile != null
    || builtins.match ".*x86_64-darwin.*" configFile != null;

  # Generate NixOS configurations from machines directory
  mkNixosConfigurations = {
    machinesPath ? ../machines,
    inputs,
    outputs,
    lib ? lib,
    extraSpecialArgs ? {},
  }: let
    hostDirs = lib.my.getHostDirs machinesPath;
    nixosMachines = builtins.filter (host: !(lib.my.isDarwinHost (machinesPath + "/${host}"))) hostDirs;
  in
    lib.genAttrs nixosMachines (
      hostname:
        lib.nixosSystem {
          modules = [
            (machinesPath + "/${hostname}/configuration.nix")
          ];
          specialArgs =
            {
              inherit inputs outputs;
            }
            // extraSpecialArgs;
        }
    );

  # Generate Darwin configurations from machines directory
  mkDarwinConfigurations = {
    machinesPath ? ../machines,
    inputs,
    outputs,
    lib ? lib,
    darwin,
    extraSpecialArgs ? {},
  }: let
    hostDirs = lib.my.getHostDirs machinesPath;
    darwinMachines = builtins.filter (host: lib.my.isDarwinHost (machinesPath + "/${host}")) hostDirs;
  in
    lib.genAttrs darwinMachines (
      hostname:
        darwin.lib.darwinSystem {
          modules = [
            (machinesPath + "/${hostname}")
          ];
          specialArgs =
            {
              inherit inputs outputs lib;
            }
            // extraSpecialArgs;
        }
    );

  # Generate Home Manager configurations from home-manager directory
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

  # Convenience function to generate all configurations at once
  mkAllConfigurations = {
    machinesPath ? ../machines,
    homePath ? ../home-profiles,
    inputs,
    outputs,
    lib ? lib,
    darwin,
    home-manager,
    pkgsFor,
    extraSpecialArgs ? {},
    additionalUsers ? [],
  }: {
    nixosConfigurations = lib.my.mkNixosConfigurations {
      inherit machinesPath inputs outputs lib extraSpecialArgs;
    };

    darwinConfigurations = lib.my.mkDarwinConfigurations {
      inherit machinesPath inputs outputs lib darwin extraSpecialArgs;
    };

    homeConfigurations = lib.my.mkHomeConfigurations {
      inherit homePath inputs outputs lib home-manager pkgsFor extraSpecialArgs additionalUsers;
    };
  };
}
