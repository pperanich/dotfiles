{...}: {
  # NixOS system-level Zerotier configuration
  flake.modules.nixos.zerotier = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.zerotier;
  in {
    options.features.zerotier = {
      networks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["8bd5124fd6604a44"];
        description = "List of Zerotier network IDs to join";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9993;
        description = "Zerotier service port";
      };
    };

    config = {
      # Zerotier service
      services.zerotierone = {
        enable = true;
        inherit (cfg) port;
        joinNetworks = cfg.networks;
      };

      # Firewall configuration
      networking.firewall = {
        allowedTCPPorts = [cfg.port];
        allowedUDPPorts = [cfg.port];

        # Trust Zerotier interfaces
        trustedInterfaces = ["zt+"];
      };

      # Enable IP forwarding for bridging
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };

      # Required packages
      environment.systemPackages = with pkgs; [
        zerotierone
      ];
    };
  };

  # Darwin Zerotier configuration
  flake.modules.darwin.zerotier = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.zerotier;
  in {
    options.features.zerotier = {
      networks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["8bd5124fd6604a44"];
        description = "List of Zerotier network IDs to join";
      };
    };

    config = {
      # Zerotier on macOS
      environment.systemPackages = with pkgs; [
        zerotierone
      ];

      # Note: Manual network joining required on macOS:
      # sudo zerotier-cli join <network-id>
    };
  };

  # Home Manager Zerotier tools
  flake.modules.homeManager.zerotier = {pkgs, ...}: {
    home.packages = with pkgs; [
      zerotierone
    ];
  };
}
