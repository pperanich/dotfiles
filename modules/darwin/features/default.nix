# Darwin feature modules
{lib, ...}: {
  imports = lib.flatten [
    (lib.my.relativeToRoot "modules/shared/features")
    (lib.my.scanPaths ./.)
  ];
}
