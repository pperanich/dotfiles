{ inputs, outputs, lib, config, pkgs, ... }:
let
  homePrefix = (if pkgs.stdenv.hostPlatform.isDarwin then "Users" else "home");
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  imports = [
    ./global
  ];

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      warn-dirty = false;
    };
  };

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    homeDirectory = "/${homePrefix}/${config.home.username}";
  };

  xdg.enable = true;

  # Enable home-manager and git
  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
    };
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    plugins = with pkgs; [
    {
      name = "powerlevel10k-config";
      file = "p10k.zsh";
      src = ../config/zsh/powerlevel10k-config;
    }
    {
      name = "powerlevel10k";
      file = "powerlevel10k.zsh-theme";
      src = "${zsh-powerlevel10k}/share/zsh-powerlevel10k";
    }
    ];
    historySubstringSearch.enable = true;
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
    sessionVariables = {
      CLICOLOR = 1;
    };
    initExtra = ''
      # >>> conda initialize >>>
      # !! Contents within this block are managed by 'conda init' !!
      __conda_setup="$('/Users/peranpl1/opt/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
      if [ $? -eq 0 ]; then
        eval "$__conda_setup"
      else
        if [ -f "/Users/peranpl1/opt/anaconda3/etc/profile.d/conda.sh" ]; then
          . "/Users/peranpl1/opt/anaconda3/etc/profile.d/conda.sh"
        else
          export PATH="/Users/peranpl1/opt/anaconda3/bin:$PATH"
            fi
            fi
            unset __conda_setup
      # <<< conda initialize <<<

      # if lsof -Pi :10000 -sTCP:LISTEN -t >/dev/null ; then
      #   echo "Port already bound!" >/dev/null
      # else
      #   ssh -N -f -L 10000:localhost:10000 peranpl1@peranpl1-dev1 >/dev/null
      # fi
      
      # if lsof -Pi :11009 -sTCP:LISTEN -t >/dev/null ; then
      #   echo "Port already bound!" >/dev/null
      # else
      #   ssh -N -f -L 11009:localhost:11009 peranpl1@redd-holobrain >/dev/null
      # fi
      
      # if lsof -Pi :61000 -sTCP:LISTEN -t >/dev/null ; then
      #   echo "Port already bound!" >/dev/null
      # else
      #   ssh -N -f -L 61000:localhost:5901 peranpl1@redd-holobrain >/dev/null
      # fi
      '';
  };
  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.home-manager.enable = true;
  programs.git.enable = true;
  programs.git.extraConfig = {
    protocol.file = { allow = "always"; };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
