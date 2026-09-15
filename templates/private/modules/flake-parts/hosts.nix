# machines/<host>/configuration.nix -> {nixos,darwin}Configurations.<host>.
# The platform declared by the machine selects the builder.
{ inputs, config, ... }:
let
  inherit (inputs) upstream;
  # Use upstream's extended lib, not flake-parts' lib, in machine specialArgs.
  inherit (upstream) lib;
  repo = import ../../lib/repo.nix;
  dir = ../../machines;

  classes = lib.unique (lib.attrNames upstream.modules ++ lib.attrNames config.flake.modules);
  modules = lib.genAttrs classes (
    class: (upstream.modules.${class} or { }) // (config.flake.modules.${class} or { })
  );
  specialArgs = {
    inherit lib modules;
    inputs = upstream.inputs // {
      inherit (inputs) self upstream;
    };
    outputs = config.flake;
  };

  # Choose the builder before evaluating the module system. Only force the
  # platform, leaving imports alone. It must be declared in configuration.nix
  # itself and cannot depend on config, pkgs, or other module-system arguments.
  platformOf =
    host:
    let
      f = import (dir + "/${host}/configuration.nix");
      args = lib.mapAttrs (
        name: _:
        specialArgs.${name}
          or (throw "hosts.nix: ${host}'s nixpkgs.hostPlatform must not depend on `${name}`, which only exists once the module system is running")
      ) (builtins.functionArgs f);
      attrs = if builtins.isFunction f then f args else f;
      raw =
        attrs.nixpkgs.hostPlatform
          or (throw "hosts.nix: machines/${host}/configuration.nix must set nixpkgs.hostPlatform directly, even if hardware-configuration.nix also sets it");
      unwrap = v: if v ? _type && v._type == "override" then unwrap v.content else v;
      platform = unwrap raw;
    in
    if lib.isString platform then
      platform
    else
      platform.system
        or (throw "hosts.nix: ${host}'s nixpkgs.hostPlatform must be a system string or a platform attrset");

  classOf =
    host:
    let
      platform = lib.systems.elaborate (platformOf host);
    in
    if platform.isDarwin then
      "darwin"
    else if platform.isLinux then
      "nixos"
    else
      throw "hosts.nix: ${host}'s platform ${platform.system} is neither Linux nor Darwin";

  hosts = lib.filterAttrs (
    host: type: type == "directory" && builtins.pathExists (dir + "/${host}/configuration.nix")
  ) (if builtins.pathExists dir then builtins.readDir dir else { });

  build =
    host: _:
    let
      class = classOf host;
      builder =
        if class == "darwin" then
          upstream.inputs.darwin.lib.darwinSystem
        else
          upstream.inputs.nixpkgs.lib.nixosSystem;
      nhVar = if class == "darwin" then "NH_DARWIN_FLAKE" else "NH_OS_FLAKE";
    in
    builder {
      inherit specialArgs;
      modules = [
        # $HOME expands when the shell sources this. The selector uses the
        # directory name even when networking.hostName differs from it.
        { environment.variables.${nhVar} = "$HOME/${repo.dirName}#${host}"; }
        (dir + "/${host}/configuration.nix")
      ];
    };

  hostsOfClass = class: lib.mapAttrs build (lib.filterAttrs (host: _: classOf host == class) hosts);
in
{
  flake = {
    nixosConfigurations = hostsOfClass "nixos";
    darwinConfigurations = hostsOfClass "darwin";
  };
}
