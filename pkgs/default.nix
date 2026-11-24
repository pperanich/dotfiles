# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{
  pkgs ? (import ../nixpkgs.nix) { },
}:
{
  # example = pkgs.callPackage ./example { };
  runmat = pkgs.callPackage ./runmat { };
  update-display = pkgs.callPackage ./update-display { };
  udp-broadcast-relay-redux = pkgs.callPackage ./udp-broadcast-relay-redux { };
  cf = pkgs.callPackage ./cf { };
  rexpick = pkgs.callPackage ./rexpick { };
  sketchybar-helpers = pkgs.callPackage ./sketchybar-helpers { };
  sqlite-snapshot = pkgs.callPackage ./sqlite-snapshot { };
  dotfiles-sync = pkgs.callPackage ./dotfiles-sync { };
  webos-devmode-renew = pkgs.callPackage ./webos-devmode-renew { };
  webos-tv = pkgs.callPackage ./webos-tv { };
}
