{
  config,
  pkgs,
  ...
}: let
  homePrefix =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "Users"
    else "home";
in {
  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
    };
  };
  targets.genericLinux.enable = true;
  home.homeDirectory = "/${homePrefix}/${config.home.username}";
}
