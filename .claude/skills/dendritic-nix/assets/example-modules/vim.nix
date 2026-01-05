# Vim editor configuration - dendritic pattern example
_: {
  # home-manager module for vim configuration
  flake.modules.homeManager.vim = { pkgs, ... }: {
    programs.vim = {
      enable = true;

      plugins = with pkgs.vimPlugins; [
        vim-nix        # Nix syntax highlighting
        vim-airline    # Status bar
        vim-fugitive   # Git integration
      ];

      settings = {
        number = true;
        relativenumber = true;
        expandtab = true;
        shiftwidth = 2;
        tabstop = 2;
      };

      extraConfig = ''
        " Syntax highlighting
        syntax on

        " Enable filetype detection
        filetype plugin indent on

        " Search settings
        set ignorecase
        set smartcase
        set hlsearch
        set incsearch

        " Better command-line completion
        set wildmenu
        set wildmode=longest:full,full
      '';
    };
  };

  # NixOS module (optional: install vim system-wide)
  flake.modules.nixos.vim = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.vim ];
  };

  # Darwin module (optional: install vim system-wide on macOS)
  flake.modules.darwin.vim = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.vim ];
  };
}
