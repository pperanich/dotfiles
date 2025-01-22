{ ... }:
{
  imports = [
    ../common/core
    ../common/optional/desktop
    ../common/optional/development
    ../common/optional/shell
  ];

  sops = {
    secrets = {
        "private_keys/pperanich" = { };
  };

  home = {
    username = "pperanich";
  };
}