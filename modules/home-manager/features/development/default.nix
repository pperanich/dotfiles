# Development features module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.features.development;
in {
  imports = [
    ./editors
    ./languages
    ./containers
  ];

  options.modules.home.features.development = {
    enable = lib.mkEnableOption "development tools and configurations";
  };
}
