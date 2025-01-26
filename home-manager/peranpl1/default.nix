# Home configuration for peranpl1
{
  outputs,
  ...
}: {
  imports = builtins.attrValues outputs.homeManagerModules;

  my.home = {
    enable = true;

    features = {
      development = {
        enable = true;

        editors = {
          enable = true;
          neovim.enable = true;
          vscode.enable = true;
        };

        languages = {
          enable = true;
          rust.enable = true;
          # python.enable = true;
          tex.enable = true;
        };
      };

      desktop = {
        enable = true;
        fonts.enable = true;
      };
    };
  };

  # User identity
  home = {
    username = "peranpl1";
  };
}
