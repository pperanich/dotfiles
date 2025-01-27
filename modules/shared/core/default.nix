# Core module for shared configuration across all systems
{
  lib,
  ...
}:
{
  imports = lib.flatten [
    (lib.my.scanPaths ./.)
  ];

  options.my.core = {
    enable = lib.mkEnableOption "core system configuration";
  };
}
