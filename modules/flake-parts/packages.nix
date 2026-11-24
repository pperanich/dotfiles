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
          cf
          rexpick
          personal-site
          sqlite-snapshot
          webos-devmode-renew
          webos-tv
          ;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        inherit (pkgs) udp-broadcast-relay-redux;
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        inherit (pkgs) sketchybar-helpers;
      };
    };
}
