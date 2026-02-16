_: {
  flake.modules.nixos.routerCore =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.router;
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
      options.my.router = {
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
          address = mkOption {
            type = types.str;
            readOnly = true;
            description = "Router's LAN IP address (computed from subnet)";
          };
          cidr = mkOption {
            type = types.str;
            readOnly = true;
            description = "LAN network in CIDR notation (computed from subnet)";
          };
          bridgeName = mkOption {
            type = types.str;
            readOnly = true;
            description = "LAN bridge device name";
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
        # Public computed values (derived from user-facing options)
        my.router.lan = {
          address = "${cfg.lan.subnet}.1";
          cidr = "${cfg.lan.subnet}.0/24";
          bridgeName = "br-lan";
        };

        # Internal computed values (cross-module plumbing only)
        my.router._internal = {
          dhcpStart = "${cfg.lan.subnet}.${toString cfg.lan.dhcpRange.start}";
          dhcpEnd = "${cfg.lan.subnet}.${toString cfg.lan.dhcpRange.end}";
        };

        # Build-time warnings for security-sensitive configurations
        warnings =
          lib.optional cfg.debugUplink.enable "router: debugUplink is enabled — this grants SSH access from an external network. Disable for production (my.router.debugUplink.enable = false)."
          ++
            lib.optional (cfg.ipv6.enable && cfg.ipv6.ulaPrefix == "fd00:1234:5678:9abc")
              "router: Using default ULA prefix 'fd00:1234:5678:9abc'. Generate a unique one per RFC 4193: printf 'fd%s:%s:%s' $(openssl rand -hex 1) $(openssl rand -hex 2) $(openssl rand -hex 2)";

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
          # H2: Prevent duplicate port forward collisions (same port+protocol across machines)
          {
            assertion =
              let
                allPorts = lib.concatMap (
                  m: map (pf: "${toString pf.port}/${pf.protocol}") m.portForwards
                ) cfg.machines;
              in
              allPorts == lib.unique allPorts;
            message = "router: Duplicate port forwards detected — each (port, protocol) pair must be unique across all machines";
          }
          # H2: Prevent duplicate machine IPs
          {
            assertion =
              let
                ips = map (m: m.ip) cfg.machines;
              in
              ips == lib.unique ips;
            message = "router: Duplicate machine IPs detected — each machine must have a unique IP";
          }
          # H2: Prevent duplicate machine names
          {
            assertion =
              let
                names = map (m: m.name) cfg.machines;
              in
              names == lib.unique names;
            message = "router: Duplicate machine names detected — each machine must have a unique name";
          }
        ];
      };
    };

  # Internal options (not user-facing)
  flake.modules.nixos.routerCoreInternal =
    { lib, ... }:
    {
      options.my.router._internal = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        internal = true;
        description = "Computed values for router sub-modules";
      };
    };
}
