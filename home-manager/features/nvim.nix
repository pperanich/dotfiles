{ config, pkgs, lib, inputs, ... }:
let neovim-overlay = inputs.neovim-nightly-overlay.packages.${pkgs.system};
  inherit (config.xdg) configHome;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  configBasePath = "${configHome}/dotfiles/config";

  home.sessionVariables.EDITOR = "nvim";

  programs.neovim = {
    enable = true;
    package = neovim-overlay.neovim;
  };

  xdg.configFile."nvim".source = mkOutOfStoreSymlink "${configBasePath}/nvim";

  xdg.desktopEntries = {
    nvim = {
      name = "Neovim";
      genericName = "Text Editor";
      comment = "Edit text files";
      exec = "nvim %F";
      icon = "nvim";
      mimeType = [
        "text/english"
        "text/plain"
        "text/x-makefile"
        "text/x-c++hdr"
        "text/x-c++src"
        "text/x-chdr"
        "text/x-csrc"
        "text/x-java"
        "text/x-moc"
        "text/x-pascal"
        "text/x-tcl"
        "text/x-tex"
        "application/x-shellscript"
        "text/x-c"
        "text/x-c++"
      ];
      terminal = true;
      type = "Application";
      categories = [ "Utility" "TextEditor" ];
    };
  };
}
