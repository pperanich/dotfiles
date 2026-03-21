{
  perSystem =
    { pkgs, lib, ... }:
    {
      # Custom packages are added to pkgs via the additions overlay (overlays/default.nix).
      # We re-export them here as flake outputs (nix build .#<name>).
      packages = {
        inherit (pkgs)
          runmat
          update-display
          wg-add-peer
          cf
          personal-site
          ;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        inherit (pkgs) udp-broadcast-relay-redux;
      };
    };
}
