# File exploration tools
{...}: {
  flake.modules.nixos.fileExploration = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      fzf # A command-line fuzzy finder
    ];
  };

  flake.modules.homeManager.fileExploration = {pkgs, ...}: {
    home.packages = with pkgs; [
      fzf # A command-line fuzzy finder
      choose # A human-friendly and fast alternative to cut and (sometimes) awk
      xplr # A hackable, minimal, fast TUI file explorer
    ];
  };
}