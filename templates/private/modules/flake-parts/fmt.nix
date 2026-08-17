# `nix fmt` formats the repo; `nix flake check` fails on unformatted files.
{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        deadnix.enable = true;
        nixfmt.enable = true;
        prettier.enable = true;
        shfmt.enable = true;
        statix.enable = true;
        yamlfmt.enable = true;
      };
      settings.global.excludes = [
        "*.envrc"
        "LICENSE"
        "*/.gitignore"
        "sops/*.yaml"
      ];
    };
  };
}
