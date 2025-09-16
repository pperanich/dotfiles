_: {
  # System-level bash configuration (ensure bash is available system-wide)
  flake.modules.nixos.bash = {pkgs, ...}: {
    environment.systemPackages = [pkgs.bash];
    programs.bash.enable = true;
  };

  flake.modules.darwin.bash = {pkgs, ...}: {
    environment.systemPackages = [pkgs.bash];
    programs.bash.enable = true;
  };

  # User-level bash configuration
  flake.modules.homeModules.bash = {
    config,
    pkgs,
    lib,
    ...
  }: {
    programs.bash = {
      enable = true;
      # Bash completion
      enableCompletion = true;
      shellAliases = {
        ls = "ls --color=auto";
        ll = "ls -la";
      };
      historyControl = [
        "ignoredups"
        "ignorespace"
      ];
      historySize = 10000;
      historyFile = "${config.xdg.dataHome}/bash/history";
      historyIgnore = [
        "ls"
        "cd"
        "exit"
      ];
      # Bash doesn't have a plugin system like Zsh
      # but you can include custom scripts in initExtra
      # initExtra = ''
      #   # >>> mamba initialize >>>
      #   # !! Contents within this block are managed by 'mamba init' !!
      #   export MAMBA_EXE="${pkgs.micromamba}/bin/micromamba";
      #   export MAMBA_ROOT_PREFIX="${config.home.homeDirectory}/micromamba";
      #   __mamba_setup="$('${pkgs.micromamba}/bin/micromamba' shell hook --shell bash --prefix '${config.home.homeDirectory}/micromamba' 2> /dev/null)"
      #   if [ $? -eq 0 ]; then
      #       eval "$__mamba_setup"
      #   else
      #       if [ -f "${config.home.homeDirectory}/micromamba/etc/profile.d/micromamba.sh" ]; then
      #           . "${config.home.homeDirectory}/micromamba/etc/profile.d/micromamba.sh"
      #       else
      #           export  PATH="${config.home.homeDirectory}/micromamba/bin:$PATH"  # extra space after export prevents interference from conda init
      #       fi
      #   fi
      #   unset __mamba_setup
      #   # <<< mamba initialize <<<
      #
      #   # Custom port forwarding function
      #   pfwd () {
      #     local_host_port=''${3:-$2} # If $3 is not given, use $2
      #     ssh -fNT -L 127.0.0.1:$local_host_port:127.0.0.1:$2 $1 && echo "Port forward to: http://127.0.0.1:$local_host_port"
      #   }
      #
      #   # Optional: Set up a nicer prompt (simpler alternative to powerlevel10k in Zsh)
      #   if command -v starship > /dev/null; then
      #     eval "$(starship init bash)"
      #   else
      #     # A colorful bash prompt if starship is not available
      #     # PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
      #   fi
      # '';
    };

    # Enable bash integration for other programs
    programs.dircolors.enableBashIntegration = true;
    programs.direnv.enableBashIntegration = true;
    programs.atuin.enableBashIntegration = true;
    programs.zoxide.enableBashIntegration = true;

    # Optional: Add starship for a nice prompt (alternative to powerlevel10k)
    # programs.starship = {
    #   enable = true;
    #   enableBashIntegration = true;
    # };
  };
}
