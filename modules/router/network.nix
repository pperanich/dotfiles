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
      inherit (internal) lanDevice;
      inherit (internal) routerIp;
      inherit (cfg.ipv6) ulaPrefix;
    in
    {
      config = lib.mkIf cfg.enable {
        # Kernel parameters for routing
        # Use mkForce for forwarding since nixpkgs defaults to false
        boot.kernel.sysctl = {
          "net.ipv4.conf.all.forwarding" = lib.mkForce 1;
          "net.ipv4.conf.all.rp_filter" = 1;
          "net.ipv4.conf.default.rp_filter" = 1;
          "net.ipv4.conf.${wan}.rp_filter" = 1;

          # Connection tracking tuning for high traffic
          "net.netfilter.nf_conntrack_max" = 262144;
          "net.netfilter.nf_conntrack_tcp_timeout_established" = 7200;
          "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 30;
          "net.netfilter.nf_conntrack_udp_timeout" = 30;
          "net.netfilter.nf_conntrack_udp_timeout_stream" = 180;

          # TCP performance tuning
          "net.core.rmem_max" = 16777216;
          "net.core.wmem_max" = 16777216;
          "net.ipv4.tcp_rmem" = "4096 87380 16777216";
          "net.ipv4.tcp_wmem" = "4096 65536 16777216";
          "net.core.netdev_max_backlog" = 16384;
          "net.core.somaxconn" = 8192;
          "net.ipv4.conf.br-lan.rp_filter" = 1;
        }
        // lib.optionalAttrs cfg.ipv6.enable {
          # Use mkForce since router requires forwarding enabled
          "net.ipv6.conf.all.forwarding" = lib.mkForce 1;
          "net.ipv6.conf.all.accept_ra" = 0;
          "net.ipv6.conf.all.autoconf" = 0;
          "net.ipv6.conf.all.use_tempaddr" = 0;
        };

        # Network configuration
        networking = {
          # hostName is set in machine config, not here (avoids circular dependency)
          useNetworkd = true;
          useDHCP = false;
          networkmanager.enable = lib.mkForce false;
          firewall.enable = false; # We use nftables directly
        };

        services.resolved.enable = false;

        # NTP server for LAN clients
        services.chrony = {
          enable = true;
          servers = [
            "time.cloudflare.com"
            "time.google.com"
            "pool.ntp.org"
          ];
          extraConfig = ''
            # Allow NTP client access from LAN
            allow ${cfg.lan.subnet}.0/24
            ${lib.optionalString cfg.ipv6.enable "allow ${ulaPrefix}::/64"}

            # Serve time even when not synchronized (stratum 10)
            local stratum 10
          '';
        };

        # SSH: Don't use NixOS firewall module (we control via nftables)
        services.openssh.openFirewall = false;

        # UPnP/NAT-PMP for automatic port forwarding
        # H4: ACL rules restrict forwards to non-privileged ports only (1024-65535)
        # Prevents LAN devices from exposing privileged services (SSH, DNS, etc.) via UPnP
        services.miniupnpd = lib.mkIf cfg.upnp.enable {
          enable = true;
          externalInterface = wan;
          internalIPs = [ "${cfg.lan.subnet}.0/24" ];
          natpmp = true;
          upnp = true;
          appendConfig = ''
            # Security: Only allow forwarding to/from non-privileged ports
            allow 1024-65535 ${cfg.lan.subnet}.0/24 1024-65535
            deny 0-65535 0.0.0.0/0 0-65535
          '';
        };

        systemd.network = {
          enable = true;

          # Bridge device for LAN interfaces
          netdevs = {
            "20-br-lan" = {
              netdevConfig = {
                Kind = "bridge";
                Name = "br-lan";
              };
              # Disable IGMP snooping so reflected mDNS/SSDP multicast floods
              # to all bridge ports. Phones don't send IGMP joins for link-local
              # multicast (224.0.0.x), so snooping silently drops reflected
              # discovery packets before they reach clients.
              bridgeConfig.MulticastSnooping = false;
            };
          };

          networks = {
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
              address = [ "${routerIp}/24" ] ++ lib.optional cfg.ipv6.enable "${ulaPrefix}::1/64";
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
          // (lib.listToAttrs (
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
          ))
          # Debug uplink - DHCP client to existing router for SSH access during development
          // lib.optionalAttrs cfg.debugUplink.enable {
            "05-debug-uplink" = {
              matchConfig.Name = cfg.debugUplink.interface;
              networkConfig = {
                DHCP = "yes";
                IPv6AcceptRA = true;
              };
              dhcpV4Config = {
                UseDNS = false; # Don't override router's DNS config
                RouteMetric = 1024; # Higher metric = lower priority than WAN
              };
              linkConfig.RequiredForOnline = "no"; # Don't block boot if unplugged
            };
          };
        };
      };
    };
}
