# Copy to modules/flake-parts/deploy.nix and enable the input in flake.nix.
# Rename these nodes with your machines and remove any unused example.
{ inputs, config, ... }:
let
  # Use deploy-rs's activation helpers with the package from upstream nixpkgs,
  # keeping its independent nixpkgs pin out of the deployed system closure.
  deployPkgsFor =
    system:
    let
      pkgsPlain = import inputs.nixpkgs { inherit system; };
    in
    import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.deploy-rs.overlays.default
        (_self: super: {
          deploy-rs = {
            inherit (pkgsPlain) deploy-rs;
            lib = super.deploy-rs.lib;
          };
        })
      ];
    };
  nixos = config.flake.nixosConfigurations.example-nixos;
  darwin = config.flake.darwinConfigurations.example-darwin;
in
{
  flake.deploy = {
    user = "root";
    sshUser = "example";
    remoteBuild = true;
    # Prompt for sudo over SSH; no blanket passwordless-sudo change is needed.
    interactiveSudo = true;
    magicRollback = true;
    autoRollback = true;

    nodes = {
      example-nixos = {
        # SSH aliases work here, including aliases with ProxyCommand tunnels.
        hostname = "example-nixos";
        profiles.system.path = (deployPkgsFor nixos.pkgs.stdenv.hostPlatform.system).deploy-rs.lib.activate.nixos nixos;
      };
      example-darwin = {
        hostname = "example-darwin.local";
        profiles.system.path = (deployPkgsFor darwin.pkgs.stdenv.hostPlatform.system).deploy-rs.lib.activate.darwin darwin;
      };
    };
  };
}
