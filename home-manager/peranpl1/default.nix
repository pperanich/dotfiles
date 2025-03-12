# Home configuration for peranpl1
{outputs, ...}: {
  imports = builtins.attrValues outputs.homeManagerModules;

  my.home = {
    enable = true;

    features = {
      shell.enable = true;
      work.enable = true;
      development = {
        enable = true;
        containers.enable = false;

        editors = {
          enable = true;
          neovim.enable = true;
          emacs.enable = false;
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
