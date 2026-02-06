_: {
  flake.modules.nixos.routerMdns =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.router;
      mdnsCfg = cfg.mdns;
      internal = cfg._internal;
      inherit (internal) lanDevice;
      enabled = cfg.enable && mdnsCfg.enable;

      # Build list of interfaces to allow mDNS on
      mdnsInterfaces = [
        lanDevice
      ]
      ++ mdnsCfg.extraInterfaces;
    in
    {
      options.features.router.mdns = {
        enable = lib.mkEnableOption "mDNS/Avahi for local device discovery (.local domains)";

        reflector = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable mDNS reflector to forward mDNS between interfaces.
            Required for devices on different network segments to discover each other.
          '';
        };

        extraInterfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "wg0"
            "zt0"
          ];
          description = "Additional interfaces to allow mDNS traffic on";
        };

        publish = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Publish local services via mDNS";
          };

          addresses = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Publish IP addresses";
          };

          domain = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Publish domain name";
          };

          workstation = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Publish workstation service (usually not needed for router)";
          };
        };
      };

      config = lib.mkIf enabled {
        services.avahi = {
          enable = true;

          # Reflect mDNS across interfaces (important for bridged networks)
          inherit (mdnsCfg) reflector;

          # Only allow on LAN interfaces
          allowInterfaces = mdnsInterfaces;

          # Don't open wide to the world
          openFirewall = false;

          # Publishing settings
          publish = {
            inherit (mdnsCfg.publish) enable;
            inherit (mdnsCfg.publish) addresses;
            inherit (mdnsCfg.publish) domain;
            inherit (mdnsCfg.publish) workstation;
          };

          # Enable NSS module for .local resolution
          nssmdns4 = true;
          nssmdns6 = cfg.ipv6.enable;

          # Domain settings
          domainName = "local";
          browseDomains = [ "local" ];
        };

        # Add firewall rules for mDNS (UDP 5353) in a separate table
        # Priority -10 ensures these rules are evaluated before the main filter (priority 0)
        networking.nftables.tables.mdnsV4 = {
          family = "ip";
          content = ''
            set mdns_ifaces {
              typeof iifname
              elements = { ${lib.concatMapStringsSep ", " (i: ''"${i}"'') mdnsInterfaces} }
            }

            chain input {
              type filter hook input priority -10; policy accept;
              iifname @mdns_ifaces udp dport 5353 accept comment "mDNS"
            }
          '';
        };

        networking.nftables.tables.mdnsV6 = lib.mkIf cfg.ipv6.enable {
          family = "ip6";
          content = ''
            set mdns_ifaces {
              typeof iifname
              elements = { ${lib.concatMapStringsSep ", " (i: ''"${i}"'') mdnsInterfaces} }
            }

            chain input {
              type filter hook input priority -10; policy accept;
              iifname @mdns_ifaces udp dport 5353 accept comment "mDNS IPv6"
            }
          '';
        };
      };
    };
}
