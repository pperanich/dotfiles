{ config, pkgs, lib, inputs, ... }:
let
  inherit (config.home) homeDirectory;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.sessionVariables = { EDITOR = "nvim"; };
  home.packages = with pkgs; [
    fzf
    pkg-config
    mktemp
    llvmPackages_16.clang-unwrapped
  ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    extraConfig = ''
      lua <<EOF
        -- require("kickstart")
        -- bootstrap lazy.nvim, LazyVim and your plugins
        require("config.lazy")
      EOF
    '';

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
    ];
  };

  xdg.configFile."nvim/lua/".source = mkOutOfStoreSymlink "${homeDirectory}/dotfiles/config/nvim/lua/";
}
