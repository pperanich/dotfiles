# Development features module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.development;
in {
  imports = [
    ./editors
    ./languages
    ./containers
  ];

  options.my.home.features.development = {
    enable = lib.mkEnableOption "development tools and configurations";
  };
}
