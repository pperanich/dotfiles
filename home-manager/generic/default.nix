{outputs, ...}: {
  imports = builtins.attrValues outputs.homeManagerModules;

  my.home = {
    enable = true;
    sops.enable = false;

    features = {
      shell.enable = true;
      shell.bash.enable = false;
      work.enable = true;
      development = {
        enable = true;

        editors = {
          enable = true;
          neovim.enable = true;
          vscode.enable = true;
          emacs.enable = false;
        };
      };

      desktop = {
        enable = false;
        fonts.enable = true;
      };
    };
  };
}
