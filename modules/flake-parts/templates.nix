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
      description = "Private machines from a public dendritic config, private dotfiles, host-key secrets, optional deploy-rs";
      welcomeText = ''
        Next steps:
          1. point inputs.upstream in flake.nix at your public config
          2. git init && git add -A   (flakes only see tracked files)
          3. rename the example user and machines; set the checkout path in lib/repo.nix
          4. follow README.md to prepare host keys and encrypt secrets before switching
          5. optional remote deployment: optional/deploy-rs/README.md
      '';
    };

    default = self.templates.dendritic;
  };
}
