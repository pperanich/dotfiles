{ ... }:
{
  imports = [
    ../common/core
    ../common/optional/desktop
    ../common/optional/development
    ../common/optional/shell
    inputs.nix-index-database.hmModules.nix-index
    { programs.nix-index-database.comma.enable = true; }
  ];

  sops = {
    secrets = {
        "private_keys/peranpl1" = { };
  };

  home = {
    username = "peranpl1";
  };
}