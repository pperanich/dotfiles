# Zsh configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.shell;
in {
  options.my.home.features.shell.zsh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Whether to enable Zsh configuration";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.zsh.enable) {
    programs = {
      zsh = {
        enable = true;
        completionInit = "autoload -U compinit && compinit -i";
        shellAliases = {
          ls = "ls --color=auto";
          ll = "ls -la";
        };
        history = {
          size = 10000;
          path = "${config.xdg.dataHome}/zsh/history";
        };
        plugins = with pkgs; [
          {
            name = "powerlevel10k-config";
            file = "p10k.zsh";
            src = lib.my.relativeToRoot "home/.config/zsh/powerlevel10k-config";
          }
          {
            name = "powerlevel10k";
            file = "powerlevel10k.zsh-theme";
            src = "${zsh-powerlevel10k}/share/zsh-powerlevel10k";
          }
        ];
        historySubstringSearch.enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        initExtra = ''
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

          pfwd () {
            local_host_port=''${3:-$2} # If $3 is not given, use $2
            ssh -fNT -L 127.0.0.1:$local_host_port:127.0.0.1:$2 $1 && echo "Port forward to: http://127.0.0.1:$local_host_port"
          }

          export OPAL_API_KEY=$(cat /run/secrets/opal_api_key)
          export OPENAI_API_KEY=$(cat /run/secrets/openai_api_key)
          export ASSEMBLYAI_API_KEY=$(cat /run/secrets/assemblyai_api_key)
          export HUGGING_FACE_HUB_TOKEN=$(cat /run/secrets/hugging_face_hub_token)
          export ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_api_key)
          export MISTRAL_API_KEY=$(cat /run/secrets/mistral_api_key)
        '';
      };
      dircolors = {
        enableZshIntegration = true;
      };
      direnv = {
        enableZshIntegration = true;
      };
      atuin = {
        enableZshIntegration = true;
      };
      zoxide = {
        enableZshIntegration = true;
      };
    };
  };
}
