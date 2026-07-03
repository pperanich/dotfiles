# Neovim editor configuration
_: {
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    {
      home.sessionVariables = {
        EDITOR = "nvim";
      };

      home.packages = with pkgs; [
        # nvim config is managed manually (~/.config/nvim symlinked into this
        # repo's home/.config/nvim, plugins via LazyVim/lazy.nvim). Install the
        # binary only — do NOT use programs.neovim, which since home-manager
        # 868d0a6 emits ~/.config/nvim/init.lua and clobbers the manual config.
        neovim

        # Common dependencies for modern text editing
        ripgrep # Required for modern text search
        fd # Required for file finding
        fzf # Fuzzy finder
        pkg-config # Required for some nvim plugins
        unzip
        # gcc
        python3
      ];
    };
}
