# Formatting configuration with treefmt-nix
# Provides automatic code formatting across multiple languages
{
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.treefmt-nix.flakeModule
    inputs.git-hooks.flakeModule  # Optional: pre-commit hooks
  ];

  perSystem = { self', ... }: {
    treefmt = {
      # Mark the project root for treefmt
      projectRootFile = "flake.nix";

      # Enable formatters for different file types
      programs = {
        deadnix.enable = true;      # Remove dead Nix code
        jsonfmt.enable = true;       # Format JSON
        nixfmt.enable = true;        # Format Nix (or use alejandra/nixpkgs-fmt)
        prettier.enable = true;      # Format JS/TS/CSS/HTML/MD
        shfmt.enable = true;         # Format shell scripts
        statix.enable = true;        # Nix linter
        yamlfmt.enable = true;       # Format YAML
      };

      # Exclude files from formatting
      settings = {
        global.excludes = [
          "*.envrc"
          ".editorconfig"
          "*.directory"
          "*.face"
          "*.fish"
          "*.png"
          "*.toml"
          "*.svg"
          "*.xml"
          "*/.gitignore"
          "LICENSE"
        ];
      };
    };

    # Optional: Set up pre-commit hook for formatting
    pre-commit.settings.hooks.nix-fmt = {
      enable = true;
      entry = lib.getExe self'.formatter;
    };
  };
}
