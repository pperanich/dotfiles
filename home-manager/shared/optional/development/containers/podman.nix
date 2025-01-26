{pkgs, ...}: {
  home.packages = with pkgs; [
    podman
    qemu
    gvproxy
  ];
}
