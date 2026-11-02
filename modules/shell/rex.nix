# Install Rex support without taking ownership of the Stow-managed config files.
{ config, inputs, ... }:
let
  profileSupport = {
    # useUserPackages adds an outer OS profile around Home Manager's environment.
    # Both Darwin and NixOS filter share/ here, even though HM links everything.
    environment.pathsToLink = [ "/share/rexpick" ];
  };
in
{
  flake.modules = {
    darwin.rex = profileSupport;
    nixos.rex = profileSupport;

    homeManager.rex =
      { pkgs, ... }:
      {
        imports = [ inputs.rex.homeManagerModules.default ];

        programs.rex = {
          enable = true;
          config = null; # home/.config/rex/init.lua
          sshGuard = false; # home/.ssh/config includes home/.config/rex/ssh_config
        };

        # No services.rex: the macOS app owns its server. Linux service enablement
        # is a separate host decision, not a side effect of installing the CLI.
        home.packages = [ pkgs.rexpick ];
      };
  };

  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    {
      checks = lib.optionalAttrs (builtins.hasAttr system inputs.rex.packages) {
        rexpick-profile = pkgs.callPackage ../../pkgs/rexpick/tests/profile.nix {
          inherit (inputs.rex.packages.${system}) rex;
          profilePaths =
            if pkgs.stdenv.hostPlatform.isDarwin then
              config.flake.darwinConfigurations.pp-ml1.config.environment.pathsToLink
            else
              config.flake.nixosConfigurations.pp-ld1.config.environment.pathsToLink;
        };
      };
    };
}
