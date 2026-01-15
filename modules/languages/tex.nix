# TeX/LaTeX development environment
_: {
  flake.modules = {
    homeManager.tex =
      { pkgs, ... }:
      {
        programs.texlive = {
          enable = true;
          # Add comprehensive LaTeX packages
          extraPackages = tpkgs: {
            inherit (tpkgs)
              scheme-full
              collection-latexextra
              collection-fontsextra
              collection-bibtexextra
              # collection-mathextra
              collection-formatsextra
              collection-context
              ;
          };
        };

        # Additional useful packages for document creation
        home.packages = with pkgs; [
          # PDF manipulation
          poppler_utils

          # Image conversion
          imagemagick

          # Bibliography management
          # jabref
        ];
      };

    # System-level packages for LaTeX development
    nixos.tex =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          # System-wide LaTeX installation for build servers
          texlive.combined.scheme-full

          # Document viewers
          evince
          okular
        ];
      };

    # macOS-specific packages
    darwin.tex =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          # macOS-specific document tools
          texlive.combined.scheme-full
        ];

        # Homebrew casks for macOS GUI applications
        homebrew.casks = [
          "skim" # PDF viewer with LaTeX support
          "texshop" # LaTeX editor
        ];
      };
  };
}
