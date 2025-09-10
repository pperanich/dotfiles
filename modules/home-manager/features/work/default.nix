# Work-specific features
{lib, ...}: {
  imports = [
    ./aplnis.nix
  ];

  options.my.home.features.work = {
    enable = lib.mkEnableOption "work-specific features";
  };
}
