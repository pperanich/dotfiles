{ inputs, outputs, lib, config, pkgs, ... }:
let
  homePrefix = (if pkgs.stdenv.hostPlatform.isDarwin then "Users" else "home");
in
{
  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      warn-dirty = false;
    };
  };


  home = {
    homeDirectory = "/${homePrefix}/${config.home.username}";
  };
}
