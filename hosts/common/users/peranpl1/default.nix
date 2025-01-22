{ pkgs, config, inputs, lib, ... }:
{
  imports = if pkgs.stdenv.isDarwin then [ ./darwin.nix ] else [ ./nixos.nix ];

  users = {
    users.peranpl1 = {
      openssh.authorizedKeys.keys = [
        (builtins.readFile ./id_ed25519.pub)
      ];
      shell = pkgs.zsh;
      packages = [ pkgs.home-manager ];
    };
  };
  programs.zsh.enable = true;

  nix.settings.trusted-users = [ "peranpl1" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit pkgs inputs;
    };
    users.peranpl1.imports = lib.flatten (
      [
        (
          { config, ... }:
          # import (lib.custom.relativeToRoot "home-manager/peranpl1/${networking.hostName}.nix") {
          import (lib.custom.relativeToRoot "home-manager/peranpl1") {
            inherit
              pkgs
              inputs
              config
              lib
              ;
          }
        )
      ]
    );
  };
}
