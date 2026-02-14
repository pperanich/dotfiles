# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{
  pkgs ? (import ../nixpkgs.nix) { },
}:
{
  # example = pkgs.callPackage ./example { };
  aplnis-env = pkgs.callPackage ./aplnis-env { };
  ai-buddy = pkgs.callPackage ./ai-buddy { };
  devai = pkgs.callPackage ./devai { };
  update-display = pkgs.callPackage ./update-display { };
  udp-broadcast-relay-redux = pkgs.callPackage ./udp-broadcast-relay-redux { };
  wg-add-peer = pkgs.callPackage ./wg-add-peer { };
  cf-dns = pkgs.callPackage ./cf-dns { };
}
