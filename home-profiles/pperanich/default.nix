# Home configuration for pperanich
{outputs, ...}: {
  imports = builtins.attrValues outputs.homeManagerModules;

  my.home = {
    enable = true;

    features = {
      shell.enable = true;
      development = {
        enable = true;

        editors = {
          enable = true;
          neovim.enable = true;
          vscode.enable = true;
          emacs.enable = false;
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
    username = "pperanich";
  };
}
