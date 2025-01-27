{lib, ...}: {
  imports = lib.flatten [
    (lib.my.scanPaths ./.)
  ];
}
