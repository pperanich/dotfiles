{ inputs, outputs, lib, config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      ls="ls --color=auto";
      ll = "ls -la";
      conda = "micromamba";
    };
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    plugins = with pkgs; [
    {
      name = "powerlevel10k-config";
      file = "p10k.zsh";
      src = ../../config/zsh/powerlevel10k-config;
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
  };
  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
  };
}

