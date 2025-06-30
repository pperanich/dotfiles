# Home configuration for mxwbio
{outputs, ...}: {
  imports = builtins.attrValues outputs.homeManagerModules;

  my.home = {
    enable = true;
    sops.enable = false;

    features = {
      shell.enable = true;
      shell.bash.enable = false;
      development = {
        enable = true;

        editors = {
          enable = true;
          neovim.enable = true;
          vscode.enable = false;
          emacs.enable = false;
        };

      };

      desktop = {
        enable = false;
        fonts.enable = true;
      };
    };
  };

  # User identity
  home = {
    username = "mxwbio";
  };
}
