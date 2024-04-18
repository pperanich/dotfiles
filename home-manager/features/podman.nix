{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.lib.meta) mkMutableSymlink;
in
{
  home.packages = with pkgs; [
    podman
    qemu
    gvproxy
  ];

  # xdg.configFile."containers/containers.conf".text = ''
  #   [engine]
  #   helper_binaries_dir = ["${pkgs.gvproxy}/bin"]
  # '';
}
