# Virtualization modules
{
  imports = [
    ./docker.nix
    ./podman.nix
    ./qemu.nix
    ./lxd.nix
    ./k3s.nix
  ];
}
