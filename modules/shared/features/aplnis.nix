{
  config,
  lib,
  ...
}: let
  cfg = config.my.features.work;
in {
  options.my.features.work = {
    enable = lib.mkEnableOption "Work Configurations";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs = {
      overlays = [ (import ../../../overlays/aplnis-overlay.nix) ];
      config = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
      };
    };
  };
}

