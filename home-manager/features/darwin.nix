{ inputs, pkgs, config, lib, ... }:
let
  inherit (config.lib.meta) mkMutableSymlink;
in
{
  home.packages = with pkgs; [ ];
}
