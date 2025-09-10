{lib, ...}: {
  imports = lib.flatten [
    (lib.my.scanPaths ./.)
  ];

  users.mutableUsers = false;
}
