# Library functions for dotfiles management
{ lib, ... }:
{
  # Use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;

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
