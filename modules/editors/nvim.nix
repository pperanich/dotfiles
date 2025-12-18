# Neovim editor configuration
_: {
  flake.modules.homeManager.nvim =
    { pkgs, ... }:
    {
      home.sessionVariables = {
        EDITOR = "nvim";
      };

      home.packages = with pkgs; [
        # Common dependencies for modern text editing
        ripgrep # Required for modern text search
        fd # Required for file finding
        fzf # Fuzzy finder
        pkg-config # Required for some nvim plugins
        unzip
        gcc
        python3
      ];

      programs.neovim = {
        enable = true;
        package = pkgs.neovim;
      };
    };
}
