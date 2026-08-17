{ self, ... }:
{
  flake.templates = {
    dendritic = {
      path = ../../templates/dendritic;
      description = "Dendritic Nix config: flake-parts + import-tree, NixOS/darwin/home-manager, sops-nix, optional clan";
      welcomeText = ''
        Next steps:
          1. git init && git add -A   (flakes only see tracked files)
          2. nix develop && nix flake check
          3. rename the example user, then follow docs/sops.md
      '';
    };
    default = self.templates.dendritic;
  };
}
