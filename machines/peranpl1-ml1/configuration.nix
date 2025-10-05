# Host configuration for peranpl1-ml1 (macOS laptop)
{
  modules,
  ...
}:
{
  imports = with modules.darwin; [
    # Core system configuration
    base

    # User setup
    peranpl1

    # Development environment
    rust

    # Work environment
    aplnis
  ];

  # Host-specific configuration
  networking.hostName = "peranpl1-ml1";
  nixpkgs.hostPlatform = "x86_64-darwin";
}
