{ inputs, outputs, lib, config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      ls="ls --color=auto";
      ll = "ls -la";
      # conda = "micromamba";
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
    syntaxHighlighting.enable = true;
    initExtra=''
      # >>> mamba initialize >>>
      # !! Contents within this block are managed by 'mamba init' !!
      export MAMBA_EXE="${pkgs.micromamba}/bin/micromamba";
      export MAMBA_ROOT_PREFIX="${config.home.homeDirectory}/micromamba";
      __mamba_setup="$('${pkgs.micromamba}/bin/micromamba' shell hook --shell zsh --prefix '${config.home.homeDirectory}/micromamba' 2> /dev/null)"
      if [ $? -eq 0 ]; then
          eval "$__mamba_setup"
      else
          if [ -f "${config.home.homeDirectory}/micromamba/etc/profile.d/micromamba.sh" ]; then
              . "${config.home.homeDirectory}/micromamba/etc/profile.d/micromamba.sh"
          else
              export  PATH="${config.home.homeDirectory}/micromamba/bin:$PATH"  # extra space after export prevents interference from conda init
          fi
      fi
      unset __mamba_setup
      # <<< mamba initialize <<<
    '';
  };
  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
}

