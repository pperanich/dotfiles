# Optional features that can be enabled per-host
{lib, ...}: {
  imports = lib.flatten [
    (lib.my.scanPaths ./.)
  ];
}

