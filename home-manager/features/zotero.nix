{
  config,
  lib,
  pkgs,
  ...
}: let
in {
  home.packages = with pkgs; [
    (lib.mkIf pkgs.stdenv.hostPlatform.isLinux zotero)
  ];
}
