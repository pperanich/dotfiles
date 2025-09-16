_: {
  flake.modules.nixos.nixDevelopment = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      nh # NH reimplements some basic nix commands
      nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
      nvd # Nix/NixOS package version diff tool
    ];
  };

  flake.modules.homeModules.nixDevelopment = {pkgs, ...}: {
    home.packages = with pkgs; [
      nh # NH reimplements some basic nix commands
      nix-output-monitor # Processes output of Nix commands to show helpful and pretty information
      nvd # Nix/NixOS package version diff tool
      statix # Lints and suggestions for the nix programming language
      nil # Nix language server for better editor support
      nixfmt-rfc-style # Official Nix formatter following RFC style
      deadnix # Find and remove unused code in .nix source files
      nix-tree # Interactively browse dependency graphs of Nix derivations
    ];
  };
}
