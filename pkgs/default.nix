# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{
  pkgs ? (import ../nixpkgs.nix) { },
  inputs ? { },
}:
{
  # example = pkgs.callPackage ./example { };
  runmat = pkgs.callPackage ./runmat { };
  update-display = pkgs.callPackage ./update-display { };
  udp-broadcast-relay-redux = pkgs.callPackage ./udp-broadcast-relay-redux { };
  wg-add-peer = pkgs.callPackage ./wg-add-peer { };
  cf = pkgs.callPackage ./cf { };
  personal-site = pkgs.callPackage ./personal-site {
    personal-site-src = inputs.personal-site;
  };
}
