# This is just an example, you should generate yours with nixos-generate-config and put it in here.
{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = ["noatime"];
    };
  };

  # Set your system kind (needed for flakes)
  nixpkgs.hostPlatform = "aarch64-linux";
}
