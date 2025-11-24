_: {
  flake.modules.nixos.routerNetwork =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.router;
      internal = cfg._internal;
      wan = cfg.wan.interface;
      lanDevice = internal.lanDevice;
      useBridge = internal.useBridge;
      routerIp = internal.routerIp;
      ulaPrefix = cfg.ipv6.ulaPrefix;
    in
    {
      config = lib.mkIf cfg.enable {
        # Kernel parameters for routing
        boot.kernel.sysctl = {
          "net.ipv4.conf.all.forwarding" = true;
          "net.ipv4.conf.default.rp_filter" = 2;
          "net.ipv4.conf.${wan}.rp_filter" = 2;
        } // lib.optionalAttrs useBridge {
          "net.ipv4.conf.br-lan.rp_filter" = 2;
        } // lib.optionalAttrs cfg.ipv6.enable {
          "net.ipv6.conf.all.forwarding" = true;
          "net.ipv6.conf.all.accept_ra" = 0;
          "net.ipv6.conf.all.autoconf" = 0;
          "net.ipv6.conf.all.use_tempaddr" = 0;
        };

        # Network configuration
        networking = {
          hostName = cfg.hostname;
          useNetworkd = true;
          useDHCP = false;
          networkmanager.enable = lib.mkForce false;
          firewall.enable = false; # We use nftables directly
        };

        systemd.network = {
          enable = true;

          # Bridge device (if multiple LAN interfaces)
          netdevs = lib.mkIf useBridge {
            "20-br-lan" = {
              netdevConfig = {
                Kind = "bridge";
                Name = "br-lan";
              };
            };
          };

          networks =
            {
              # WAN interface
              "20-wan" = {
                matchConfig.Name = wan;
                networkConfig = {
                  DHCP = if cfg.wan.useDHCP then "yes" else "no";
                  IPv4Forwarding = true;
                  IPv6Forwarding = cfg.ipv6.enable;
                  IPv6AcceptRA = cfg.ipv6.enable;
                };
                linkConfig.RequiredForOnline = "routable";
              };

              # LAN bridge or interface
              "10-lan" = {
                matchConfig.Name = lanDevice;
                address =
                  [ "${routerIp}/24" ]
                  ++ lib.optional cfg.ipv6.enable "${ulaPrefix}::1/64";
                networkConfig = {
                  ConfigureWithoutCarrier = true;
                  DHCPPrefixDelegation = cfg.ipv6.enable;
                  IPv6SendRA = cfg.ipv6.enable;
                  IPv6AcceptRA = false;
                };
                ipv6Prefixes = lib.mkIf cfg.ipv6.enable [
                  {
                    AddressAutoconfiguration = true;
                    OnLink = true;
                    Prefix = "${ulaPrefix}::/64";
                  }
                ];
                linkConfig.RequiredForOnline = "no";
              };
            }
            # Add bridge member configs if using bridge
            // lib.optionalAttrs useBridge (
              lib.listToAttrs (
                map (
                  iface:
                  lib.nameValuePair "30-${iface}-lan" {
                    matchConfig.Name = iface;
                    networkConfig = {
                      Bridge = "br-lan";
                      ConfigureWithoutCarrier = true;
                    };
                  }
                ) cfg.lan.interfaces
              )
            );
        };

        # Ensure nftables starts before network
        systemd.services.nftables = {
          after = [ "sysinit.target" ];
          before = [ "network-pre.target" ];
          wants = [ "network-pre.target" ];
        };
      };
    };
}
