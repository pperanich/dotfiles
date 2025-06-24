# Core shell configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home;
in {
  config = lib.mkIf cfg.enable {
    # Basic shell environment
    home.sessionVariables = {
      SHELL = "${pkgs.zsh}/bin/zsh";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      MANPAGER = "less -R --use-color -Dd+r -Du+b";
    };

    # Basic shell configuration
    programs = {
      # zsh.enable = true; # Default shell
      # bash.enable = true;
      # atuin.enable = true;
    };
  };
}
