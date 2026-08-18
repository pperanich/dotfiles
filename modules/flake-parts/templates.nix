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
    private = {
      path = ../../templates/private;
      description = "Private machines built from a public dendritic config, one input, no deployment tool";
      welcomeText = ''
        Next steps:
          1. point inputs.upstream in flake.nix at your public config
          2. git init && git add -A   (flakes only see tracked files)
          3. rename the example user and machine, then read docs/upstream-contract.md
          4. nh os switch .   (or nixos-rebuild / darwin-rebuild)
      '';
    };

    default = self.templates.dendritic;
  };
}
