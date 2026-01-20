# Git configuration - dendritic pattern example
_: {
  flake.modules = {
    # home-manager Git configuration
    homeManager.git =
      { pkgs, ... }:
      {
        programs.git = {
          enable = true;
          userName = "Your Name"; # Override in user profiles
          userEmail = "your.email@example.com"; # Override in user profiles

          aliases = {
            st = "status";
            co = "checkout";
            br = "branch";
            ci = "commit";
            unstage = "reset HEAD --";
            last = "log -1 HEAD";
            visual = "log --graph --all --decorate --oneline";
          };

          extraConfig = {
            init.defaultBranch = "main";
            pull.rebase = true;
            push.autoSetupRemote = true;
            core.editor = "vim";

            # Better diff algorithm
            diff.algorithm = "histogram";

            # Reuse recorded resolution of conflicted merges
            rerere.enabled = true;
          };

          ignores = [
            # Editor files
            ".vscode/"
            ".idea/"
            "*.swp"
            "*.swo"
            "*~"

            # OS files
            ".DS_Store"
            "Thumbs.db"

            # Build artifacts
            "result"
            "result-*"
            ".direnv/"
          ];
        };

        home.packages = with pkgs; [
          git
          gh # GitHub CLI
        ];
      };

    # NixOS: Install git system-wide
    nixos.git =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.git ];
      };

    # Darwin: Install git system-wide (macOS)
    darwin.git =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.git ];
      };
  };
}
