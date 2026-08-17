# Which hosts exist: machines/nixos/<host>/configuration.nix  -> nixosConfigurations.<host>
#                    machines/darwin/<host>/configuration.nix -> darwinConfigurations.<host>
#
# What a host *is* lives in lib.nix (flake.lib.mkHost).
#
# If you switch to clan (optional/clan/), delete this file — clan builds these
# outputs from its inventory instead.
{
  inputs,
  config,
  ...
}:
let
  inherit (config.flake) lib;

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

  # Hosts contributed by an optional private input (see private.nix). Simple,
  # but it makes every output of this flake unevaluable without access to that
  # repo — including `templates`. When this flake must stay publicly
  # evaluable, have the private flake call flake.lib.mkHost instead.
  privateHosts = class: ((inputs.private or { }).machines or { }).${class} or { };

  hostsIn =
    class:
    lib.mapAttrs (_: path: lib.mkHost { inherit class path; }) (localHosts class // privateHosts class);
in
{
  flake = {
    nixosConfigurations = hostsIn "nixos";
    darwinConfigurations = hostsIn "darwin";
  };
}
