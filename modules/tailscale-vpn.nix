_: {
  # Tailscale VPN module - Cross-platform mesh VPN service and tools
  flake.modules.nixos.tailscaleVpn = {
    config,
    pkgs,
    ...
  }: {
    services.tailscale = {
      enable = true;
      package = pkgs.tailscale;
      # Default Tailscale port
      port = 41641;
    };

    networking.firewall = {
      # Trust the Tailscale interface for secure mesh networking
      trustedInterfaces = ["tailscale0"];
      # Note: Tailscale handles port management automatically
    };

    # System packages for administration
    environment.systemPackages = with pkgs; [
      tailscale # Tailscale client and daemon
    ];
  };

  # Darwin (macOS) system configuration
  flake.modules.darwin.tailscaleVpn = {pkgs, ...}: {
    # Install Tailscale via system packages on macOS
    environment.systemPackages = with pkgs; [
      tailscale
    ];

    # Note: macOS Tailscale typically runs as a user-space application
    # System-level daemon configuration may require manual setup
  };

  # User-level Tailscale tools and utilities
  flake.modules.homeModules.tailscaleVpn = {pkgs, ...}: {
    home.packages = with pkgs; [
      tailscale # Tailscale CLI for user operations
    ];

    # Optional: Add shell aliases for common Tailscale operations
    programs.bash.shellAliases = {
      ts-status = "tailscale status";
      ts-up = "tailscale up";
      ts-down = "tailscale down";
      ts-ip = "tailscale ip";
    };

    programs.zsh.shellAliases = {
      ts-status = "tailscale status";
      ts-up = "tailscale up";
      ts-down = "tailscale down";
      ts-ip = "tailscale ip";
    };

    programs.fish.shellAliases = {
      ts-status = "tailscale status";
      ts-up = "tailscale up";
      ts-down = "tailscale down";
      ts-ip = "tailscale ip";
    };
  };
}
