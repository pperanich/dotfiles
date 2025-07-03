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

  # Get all host directories that contain a default.nix file
  getHostDirs = hostsPath: 
    lib.attrNames (
      lib.attrsets.filterAttrs (
        name: type:
          type == "directory" && builtins.pathExists (hostsPath + "/${name}/default.nix")
      ) (builtins.readDir hostsPath)
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
  isDarwinHost = hostPath: 
    let
      configFile = builtins.readFile (hostPath + "/default.nix");
    in
      builtins.match ".*darwinModules.*" configFile != null ||
      builtins.match ".*aarch64-darwin.*" configFile != null ||
      builtins.match ".*x86_64-darwin.*" configFile != null;

  # Generate NixOS configurations from hosts directory
  mkNixosConfigurations = {
    hostsPath ? ../hosts,
    inputs,
    outputs,
    lib ? lib,
    extraSpecialArgs ? {}
  }: let
    hostDirs = lib.my.getHostDirs hostsPath;
    nixosHosts = builtins.filter (host: !(lib.my.isDarwinHost (hostsPath + "/${host}"))) hostDirs;
  in
    lib.genAttrs nixosHosts (hostname: 
      lib.nixosSystem {
        modules = [
          (hostsPath + "/${hostname}")
        ];
        specialArgs = {
          inherit inputs outputs;
        } // extraSpecialArgs;
      }
    );

  # Generate Darwin configurations from hosts directory
  mkDarwinConfigurations = {
    hostsPath ? ../hosts,
    inputs,
    outputs,
    lib ? lib,
    darwin,
    extraSpecialArgs ? {}
  }: let
    hostDirs = lib.my.getHostDirs hostsPath;
    darwinHosts = builtins.filter (host: lib.my.isDarwinHost (hostsPath + "/${host}")) hostDirs;
  in
    lib.genAttrs darwinHosts (hostname:
      darwin.lib.darwinSystem {
        modules = [
          (hostsPath + "/${hostname}")
        ];
        specialArgs = {
          inherit inputs outputs lib;
        } // extraSpecialArgs;
      }
    );

  # Generate Home Manager configurations from home-manager directory
  mkHomeConfigurations = {
    homePath ? ../home-manager,
    inputs,
    outputs,
    lib ? lib,
    home-manager,
    pkgsFor,
    extraSpecialArgs ? {},
    # Additional users to create for generic configuration
    additionalUsers ? []
  }: let
    homeDirs = lib.my.getHomeDirs homePath;
    
    # Regular user configurations (not generic)
    userConfigs = lib.genAttrs 
      (builtins.filter (name: name != "generic") homeDirs)
      (username: home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor.x86_64-linux;
        modules = [
          (homePath + "/${username}")
        ];
        extraSpecialArgs = {
          inherit inputs outputs;
          lib = lib.extend (_: _: home-manager.lib);
        } // extraSpecialArgs;
      });

    # Generic configurations for additional users
    genericConfigs = 
      if builtins.elem "generic" homeDirs then
        lib.genAttrs additionalUsers (username:
          home-manager.lib.homeManagerConfiguration {
            pkgs = pkgsFor.x86_64-linux;
            modules = [
              (homePath + "/generic")
              {
                home = {
                  username = username;
                };
              }
            ];
            extraSpecialArgs = {
              inherit inputs outputs;
              lib = lib.extend (_: _: home-manager.lib);
            } // extraSpecialArgs;
          }
        )
      else {};
  in
    userConfigs // genericConfigs;

  # Convenience function to generate all configurations at once
  mkAllConfigurations = {
    hostsPath ? ../hosts,
    homePath ? ../home-manager,
    inputs,
    outputs,
    lib ? lib,
    darwin,
    home-manager,
    pkgsFor,
    extraSpecialArgs ? {},
    additionalUsers ? []
  }: {
    nixosConfigurations = lib.my.mkNixosConfigurations {
      inherit hostsPath inputs outputs lib extraSpecialArgs;
    };
    
    darwinConfigurations = lib.my.mkDarwinConfigurations {
      inherit hostsPath inputs outputs lib darwin extraSpecialArgs;
    };
    
    homeConfigurations = lib.my.mkHomeConfigurations {
      inherit homePath inputs outputs lib home-manager pkgsFor extraSpecialArgs additionalUsers;
    };
  };
}
