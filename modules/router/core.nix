_: {
  flake.modules.nixos.routerCore =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.router;
      inherit (lib) mkEnableOption mkOption types;

      # Validated types
      octetType = types.ints.between 1 254;
      portType = types.ints.between 1 65535;
      macType = types.strMatching "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$";

      machineSubmodule = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Machine hostname";
          };
          ip = mkOption {
            type = octetType;
            description = "Static IP address (last octet, 1-254)";
          };
          mac = mkOption {
            type = macType;
            description = "MAC address for DHCP reservation (format: XX:XX:XX:XX:XX:XX)";
          };
          portForwards = mkOption {
            type = types.listOf (
              types.submodule {
                options = {
                  port = mkOption {
                    type = portType;
                    description = "Port to forward (1-65535)";
                  };
                  protocol = mkOption {
                    type = types.enum [
                      "tcp"
                      "udp"
                    ];
                    default = "tcp";
                    description = "Protocol to forward";
                  };
                };
              }
            );
            default = [ ];
            description = "Port forwarding rules for this machine";
          };
        };
      };

      serviceSubmodule = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Service FQDN for DNS";
          };
          target = mkOption {
            type = types.str;
            description = "Target IP address";
          };
        };
      };
    in
    {
      options.features.router = {
        enable = mkEnableOption "router functionality";

        hostname = mkOption {
          type = types.str;
          default = config.networking.hostName;
          description = "Router hostname";
        };

        lan = {
          subnet = mkOption {
            type = types.str;
            default = "10.0.0";
            example = "192.168.1";
            description = "LAN subnet base (first 3 octets)";
          };
          dhcpRange = {
            start = mkOption {
              type = octetType;
              default = 100;
              description = "DHCP range start (last octet)";
            };
            end = mkOption {
              type = octetType;
              default = 200;
              description = "DHCP range end (last octet)";
            };
          };
          interfaces = mkOption {
            type = types.listOf types.str;
            example = [
              "enp2s0"
              "enp3s0"
            ];
            description = "LAN interfaces to bridge into br-lan";
          };
        };

        wan = {
          interface = mkOption {
            type = types.str;
            default = "enp1s0";
            description = "WAN interface name";
          };
          useDHCP = mkOption {
            type = types.bool;
            default = true;
            description = "Use DHCP on WAN interface";
          };
        };

        ipv6 = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable IPv6 support";
          };
          ulaPrefix = mkOption {
            type = types.str;
            default = "fd00:1234:5678:9abc";
            description = "ULA prefix for IPv6 (generate unique one)";
          };
        };

        machines = mkOption {
          type = types.listOf machineSubmodule;
          default = [ ];
          description = "Machines with static IPs and port forwarding";
        };

        services = mkOption {
          type = types.listOf serviceSubmodule;
          default = [ ];
          description = "Services for local DNS resolution";
        };

        # Sub-module toggles
        dhcp.enable = mkEnableOption "DHCP server (Kea)";
        dns.enable = mkEnableOption "DNS server (Unbound)";
        nginx.enable = mkEnableOption "nginx reverse proxy";
        upnp.enable = mkEnableOption "UPnP/NAT-PMP for automatic port forwarding (gaming, P2P)";
        # monitoring.enable is defined in routerMonitoring module with additional options

        debugUplink = {
          enable = mkEnableOption "debug uplink interface for development access";
          interface = mkOption {
            type = types.str;
            default = "enp2s0";
            description = "Interface to use as debug uplink (gets DHCP from existing router)";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # Computed helper values available to other modules
        features.router._internal = {
          lanSubnet = cfg.lan.subnet;
          lanCidr = "${cfg.lan.subnet}.0/24";
          routerIp = "${cfg.lan.subnet}.1";
          dhcpStart = "${cfg.lan.subnet}.${toString cfg.lan.dhcpRange.start}";
          dhcpEnd = "${cfg.lan.subnet}.${toString cfg.lan.dhcpRange.end}";
          lanDevice = "br-lan";
        };

        # Assertions for configuration validation
        assertions = [
          {
            assertion = cfg.lan.interfaces != [ ];
            message = "router: lan.interfaces must contain at least one interface";
          }
          {
            assertion = cfg.lan.dhcpRange.start < cfg.lan.dhcpRange.end;
            message = "router: DHCP range start must be less than end";
          }
          {
            assertion = builtins.all (
              m: m.ip < cfg.lan.dhcpRange.start || m.ip > cfg.lan.dhcpRange.end
            ) cfg.machines;
            message = "router: Static machine IPs must be outside DHCP range";
          }
          {
            assertion = builtins.all (m: m.ip != 1) cfg.machines;
            message = "router: Machine IP .1 is reserved for the router";
          }
        ];
      };
    };

  # Internal options (not user-facing)
  flake.modules.nixos.routerCoreInternal =
    { lib, ... }:
    {
      options.features.router._internal = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        internal = true;
        description = "Computed values for router sub-modules";
      };
    };
}
