# Host configuration for pp-ld1 (Linux desktop)
{
  modules,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base
    sops
    tailscale

    # User setup
    pperanich

    # Development environment
    rust

    # Offsite Google Drive Restic backup (docs/backups.md)
    backup
  ]);

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "pp-ld1";
}
