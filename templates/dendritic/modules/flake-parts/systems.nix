# Auto-discover hosts: machines/nixos/<host>/configuration.nix  -> nixosConfigurations.<host>
#                      machines/darwin/<host>/configuration.nix -> darwinConfigurations.<host>
#
# If you switch to clan (optional/clan/), delete this file — clan builds these
# outputs from its inventory instead.
{
  inputs,
  config,
  ...
}:
let
  # Imported, not taken from the module args: threading the flake-parts `lib`
  # arg into specialArgs makes the system eval recurse through _module.args.
  lib = import ../../lib/extended.nix { inherit (inputs) nixpkgs; };

  # What machine files and platform modules see. `modules` is the whole
  # flake.modules tree, so machines write `with modules.nixos; [ ... ]`.
  specialArgs = {
    inherit inputs lib;
    inherit (config.flake) modules;
    outputs = config.flake;
  };

  mkHost =
    class: hostFile:
    let
      builder =
        if class == "darwin" then inputs.darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem;
    in
    builder {
      inherit specialArgs;
      modules = [ hostFile ];
    };

  localHosts =
    class:
    let
      dir = ../../machines + "/${class}";
    in
    if !builtins.pathExists dir then
      { }
    else
      lib.genAttrs (lib.attrNames (
        lib.filterAttrs (
          host: type: type == "directory" && builtins.pathExists (dir + "/${host}/configuration.nix")
        ) (builtins.readDir dir)
      )) (host: dir + "/${host}/configuration.nix");

  # Hosts contributed by an optional private input (see private.nix):
  #   outputs = _: { machines.nixos.secret-host = ./machines/secret-host/configuration.nix; };
  privateHosts = class: ((inputs.private or { }).machines or { }).${class} or { };

  hostsIn = class: lib.mapAttrs (_: mkHost class) (localHosts class // privateHosts class);
in
{
  flake = {
    nixosConfigurations = hostsIn "nixos";
    darwinConfigurations = hostsIn "darwin";
  };
}
