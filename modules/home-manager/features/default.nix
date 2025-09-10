# Home Manager feature modules
{lib, ...}: {
  imports = lib.flatten [
    (lib.my.scanPaths ./.)
  ];
}
