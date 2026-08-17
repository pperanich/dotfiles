# Owns flake.lib: nixpkgs lib + lib.my.* + mkHost.
#
# mkHost is exported so a downstream flake can build a host against these
# modules — that's how a private repo deploys machines without this flake
# depending on it. See docs/private-repo.md.
{ inputs, config, ... }:
let
  # Imported, not taken from the module args: threading the flake-parts `lib`
  # arg into specialArgs makes the system eval recurse through _module.args.
  lib = import ../../lib/extended.nix { inherit (inputs) nixpkgs; };

  # What machine files and platform modules see. `modules` is the whole
  # flake.modules tree, so machines write `with modules.nixos; [ ... ]`.
  baseSpecialArgs = {
    inherit inputs lib;
    inherit (config.flake) modules;
    outputs = config.flake;
  };

  mkHost =
    {
      class,
      path,
      # Modules appended to the host's import list, as paths or functions
      extraModules ? [ ],
      # Merged into the `modules` specialArg, so a downstream flake's own
      # modules are importable by name: { nixos.vpnTopology = ./vpn.nix; }
      namedModules ? { },
      specialArgs ? { },
    }:
    let
      builder =
        if class == "darwin" then inputs.darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem;
    in
    builder {
      specialArgs =
        baseSpecialArgs
        // {
          modules =
            baseSpecialArgs.modules
            // lib.mapAttrs (c: mods: (baseSpecialArgs.modules.${c} or { }) // mods) namedModules;
        }
        // specialArgs;
      modules = [ path ] ++ extraModules;
    };
in
{
  flake.lib = lib // {
    inherit mkHost;
  };
}
