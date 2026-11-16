# Fleet deployment definitions via deploy-rs (root over SSH with the admin key, magicRollback).
# deploy-rs's own nixpkgs pin stays out of deployed system closures (see templates/private/docs/upstream-contract.md).
{
  inputs,
  config,
  lib,
  self,
  ...
}:
let
  mkDeployPkgs =
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
            inherit (super.deploy-rs) lib;
          };
        })
      ];
    };

  deployPkgs = lib.genAttrs [
    "x86_64-linux"
    "aarch64-linux"
  ] mkDeployPkgs;
in
{
  flake.deploy = {
    sshUser = "root";
    user = "root";
    magicRollback = true;
    autoRollback = true;

    # Nodes build on themselves: no other host is set up as a builder for them.
    # pp-ml1 has no sshd and switches locally with nh darwin switch.
    # pp-rpi1 is powered off; its node returns when it is re-imaged.
    nodes = {
      pp-router1 = {
        hostname = "pp-router1.home.arpa";
        remoteBuild = true;
        profiles.system.path =
          deployPkgs."x86_64-linux".deploy-rs.lib.activate.nixos
            self.nixosConfigurations.pp-router1;
      };
      pp-nas1 = {
        hostname = "pp-nas1.home.arpa";
        remoteBuild = true;
        profiles.system.path =
          deployPkgs."x86_64-linux".deploy-rs.lib.activate.nixos
            self.nixosConfigurations.pp-nas1;
      };
      pp-wsl1 = {
        hostname = "pp-wsl1.pp-ts";
        remoteBuild = true;
        profiles.system.path =
          deployPkgs."x86_64-linux".deploy-rs.lib.activate.nixos
            self.nixosConfigurations.pp-wsl1;
      };
    };
  };

  perSystem =
    {
      pkgs,
      ...
    }:
    let
      expectedNodes = [
        "pp-nas1"
        "pp-router1"
        "pp-wsl1"
      ];
      deployCfg = config.flake.deploy;
      actualNodes = builtins.attrNames deployCfg.nodes;
    in
    {
      checks.deploy-nodes-eval =
        assert actualNodes == expectedNodes;
        assert deployCfg.sshUser == "root";
        assert deployCfg.user == "root";
        assert !(deployCfg.interactiveSudo or false);
        assert deployCfg.magicRollback;
        assert deployCfg.autoRollback;
        assert lib.all (n: n.remoteBuild or false) (builtins.attrValues deployCfg.nodes);
        pkgs.runCommand "deploy-nodes-eval" { } ''
          cat <<'EOF' > "$out"
          nodes=${lib.concatStringsSep "," actualNodes}
          remoteBuild=all-true
          EOF
        '';
    };
}
