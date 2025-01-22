{ pkgs, config, ... }:
let
  platform = if isDarwin then "darwin" else "nixos";
in
{
  imports = [
    ./${platform}.nix
  ];

  users = {
    users.pperanich = {
      name = "pperanich";
      openssh.authorizedKeys.keys = [
        (builtins.readFile ./id_ed25519.pub)
      ];
      shell = pkgs.zsh;
      packages = [ pkgs.home-manager ];
    };
  };
  programs.zsh.enable = true;

  nix.settings.trusted-users = [ "pperanich" ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit pkgs inputs;
    };
    users.pperanich.imports = lib.flatten (
      [
        (
          { config, ... }:
          # import (lib.custom.relativeToRoot "home-manager/pperanich/${networking.hostName}.nix") {
          import (lib.custom.relativeToRoot "home-manager/pperanich") {
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
