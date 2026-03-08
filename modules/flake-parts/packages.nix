{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = {
        runmat = pkgs.callPackage ../../pkgs/runmat { };
        update-display = pkgs.callPackage ../../pkgs/update-display { };
        wg-add-peer = pkgs.callPackage ../../pkgs/wg-add-peer { };
        cf = pkgs.callPackage ../../pkgs/cf { };
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        udp-broadcast-relay-redux = pkgs.callPackage ../../pkgs/udp-broadcast-relay-redux { };
      };
    };
}
