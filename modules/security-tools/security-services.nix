# NixOS security services configuration
# systemd services, firewall rules, AppArmor, and monitoring services
_: {
  flake.modules.nixos.securityTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Enable and configure security services
    services = {
      # Enable audit daemon for comprehensive logging
      auditd.enable = true;

      # Configure fail2ban for intrusion prevention
      fail2ban = {
        enable = true;
        maxretry = 3;
        bantime = "10m";
        bantime-increment = {
          enable = true;
          multipliers = "1 2 4 8 16 32 64";
          maxtime = "168h";
          overalljails = true;
        };
      };
    };

    # Firewall configuration
    networking.firewall = {
      enable = true;
      # Close all ports by default, open only what's needed
      allowedTCPPorts = [];
      allowedUDPPorts = [];
      # Enable logging of refused connections
      logReversePathDrops = true;
      logRefusedConnections = lib.mkDefault false;
    };

    # Additional security configurations
    security = {
      # Enable AppArmor for additional security
      apparmor = {
        enable = true;
        killUnconfinedConfinement = true;
      };
    };

    # Periodic security scans
    systemd.services.lynis-scan = {
      description = "Lynis security audit";
      script = ''
        ${pkgs.lynis}/bin/lynis audit system --cronjob
      '';
      startAt = "weekly";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    # Additional auditd package for system audit daemon
    environment.systemPackages = with pkgs; [
      auditd # Linux audit daemon
    ];
  };
}
