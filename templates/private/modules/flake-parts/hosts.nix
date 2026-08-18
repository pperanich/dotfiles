# Which hosts exist:
#   machines/nixos/<host>/configuration.nix  -> nixosConfigurations.<host>
#   machines/darwin/<host>/configuration.nix -> darwinConfigurations.<host>
#
# Drop a directory in, and it is a host. Activation is plain nixos-rebuild /
# darwin-rebuild (or `nh`, which wraps both); there is no deployment tool and
# no inventory to keep in sync.
{ inputs, config, ... }:
let
  inherit (inputs) upstream;

  # The upstream's extended lib: nixpkgs.lib plus its lib.my.*. Read off its
  # flake outputs, never from this module's own `lib` argument — threading a
  # flake-parts lib into specialArgs recurses through _module.args.pkgs.
  inherit (upstream) lib;

  # Upstream's modules with this repo's own merged over them, so a local module
  # can shadow an upstream one of the same name.
  classes = lib.unique (lib.attrNames upstream.modules ++ lib.attrNames config.flake.modules);
  modules = lib.genAttrs classes (
    class: (upstream.modules.${class} or { }) // (config.flake.modules.${class} or { })
  );

  hostsIn =
    class:
    let
      dir = ../../machines + "/${class}";
      builder =
        if class == "darwin" then
          upstream.inputs.darwin.lib.darwinSystem
        else
          upstream.inputs.nixpkgs.lib.nixosSystem;
      hosts =
        if !builtins.pathExists dir then
          { }
        else
          lib.filterAttrs (
            host: type: type == "directory" && builtins.pathExists (dir + "/${host}/configuration.nix")
          ) (builtins.readDir dir);
    in
    lib.mapAttrs (
      host: _:
      builder {
        # What a machine file sees. `modules` is the merged tree above, so a
        # machine here is written exactly like one in the upstream repo.
        specialArgs = {
          inherit lib modules;
          inputs = upstream.inputs // {
            inherit (inputs) self upstream;
          };
          outputs = config.flake;
        };
        modules = [ (dir + "/${host}/configuration.nix") ];
      }
    ) hosts;
in
{
  flake = {
    nixosConfigurations = hostsIn "nixos";
    darwinConfigurations = hostsIn "darwin";
  };
}
