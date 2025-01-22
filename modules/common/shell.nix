{ config, lib, pkgs, ... }:

let
  cfg = config.my.shell;
in
{
  options.my.shell = {
    enable = lib.mkEnableOption "shell configuration";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional packages to install for shell environment";
    };

    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Shell aliases to configure";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Basic shell utilities
      bat
      exa
      fd
      fzf
      ripgrep
      tmux
      tree
      zoxide
    ] ++ cfg.extraPackages;

    programs = {
      zsh = {
        enable = true;
        enableCompletion = true;
        enableBashCompletion = true;
        
        shellAliases = {
          # Modern alternatives
          ls = "exa";
          ll = "exa -l";
          la = "exa -la";
          cat = "bat";
          find = "fd";
          grep = "rg";
          
          # Git shortcuts
          g = "git";
          ga = "git add";
          gc = "git commit";
          gco = "git checkout";
          gd = "git diff";
          gl = "git log";
          gs = "git status";
          
          # Navigation
          ".." = "cd ..";
          "..." = "cd ../..";
          
          # Additional aliases
        } // cfg.aliases;
      };

      bash = {
        enable = true;
        enableCompletion = true;
      };
    };
  };
} 