# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  # example = pkgs.callPackage ./example { };
  aplnis-env = pkgs.callPackage ./aplnis-env { };
  apple-fonts = pkgs.callPackage ./apple-fonts { };
  ai-buddy = pkgs.callPackage ./ai-buddy { };
  devai = pkgs.callPackage ./devai { };
  update-display = pkgs.callPackage ./update-display { };
  # Darwin compatibility
  logseq-darwin = pkgs.callPackage ./logseq { };
  brave-darwin = pkgs.callPackage ./brave { };
  zotero-darwin = pkgs.callPackage ./zotero { };
  # etcher-darwin = pkgs.callPackage ./etcher { };
  tailscale-darwin = pkgs.callPackage ./tailscale { };
  spotify-darwin = pkgs.callPackage ./spotify { };
  vlc-darwin = pkgs.callPackage ./vlc { };
  protonvpn-gui-darwin = pkgs.callPackage ./protonvpn-gui { };
  # Extras
  # docker-desktop = pkgs.callPackage ./docker-desktop { };
  # shottr = pkgs.callPackage ./shottr { };
}
