{ config, pkgs, lib, inputs, ... }:
let neovim-overlay = inputs.neovim-nightly-overlay.packages.${pkgs.system};
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{

  home.sessionVariables.EDITOR = "nvim";

  programs.neovim = {
    enable = true;
    package = neovim-overlay.neovim;
  };

  xdg.configFile."nvim".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/nvim";
}
