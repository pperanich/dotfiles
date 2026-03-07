{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        runmat = pkgs.callPackage ../../pkgs/runmat { };
        update-display = pkgs.callPackage ../../pkgs/update-display { };
        udp-broadcast-relay-redux = pkgs.callPackage ../../pkgs/udp-broadcast-relay-redux { };
        wg-add-peer = pkgs.callPackage ../../pkgs/wg-add-peer { };
        cf = pkgs.callPackage ../../pkgs/cf { };
      };
    };
}
