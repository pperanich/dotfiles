{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.sessionVariables = { EDITOR = "nvim"; };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    extraConfig = ''
      lua <<EOF
        require("kickstart")
      EOF
    '';

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
    ];
  };

  xdg.configFile."nvim/lua/".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/nvim/lua/";
}
