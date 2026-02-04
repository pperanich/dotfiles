{
  inputs,
  ...
}:
{
  imports = [
    inputs.treefmt-nix.flakeModule
    inputs.git-hooks.flakeModule
  ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        deadnix.enable = true;
        jsonfmt.enable = true;
        nixfmt.enable = true;
        prettier.enable = true;
        stylua.enable = true;
        shfmt.enable = true;
        statix.enable = true;
        yamlfmt.enable = true;
      };
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
  };
}
