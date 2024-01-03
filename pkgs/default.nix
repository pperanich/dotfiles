# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  # example = pkgs.callPackage ./example { };
  aplnis-env = pkgs.callPackage ./aplnis-env { };
  apple-fonts = pkgs.callPackage ./apple-fonts { };
  ai-buddy = pkgs.callPackage ./ai-buddy { };
  update-display = pkgs.callPackage ./update-display { };
  logseq = pkgs.callPackage ./logseq { };
  brave = pkgs.callPackage ./brave { };
  shottr = pkgs.callPackage ./shottr { };
  zotero = pkgs.callPackage ./zotero { };
  etcher = pkgs.callPackage ./etcher { };
  spotify = pkgs.callPackage ./spotify { };
  vlc = pkgs.callPackage ./vlc { };
  protonvpn-gui = pkgs.callPackage ./protonvpn-gui { };
  docker-desktop = pkgs.callPackage ./docker-desktop { };
}
