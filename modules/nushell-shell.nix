_: {
  # System-level nushell configuration (ensure nushell is available system-wide)
  flake.modules.nixos.nushell = {pkgs, ...}: {
    environment.systemPackages = [pkgs.nushell];
  };

  flake.modules.darwin.nushell = {pkgs, ...}: {
    environment.systemPackages = [pkgs.nushell];
  };

  # User-level nushell configuration
  flake.modules.homeModules.nushell = {
    config,
    pkgs,
    lib,
    ...
  }: {
    programs.nushell = {
      enable = true;
    };

    # Enable nushell integration for other programs
    programs.direnv.enableNushellIntegration = true;
    programs.atuin.enableNushellIntegration = true;
    programs.zoxide.enableNushellIntegration = true;
  };
}
