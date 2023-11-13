{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
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
