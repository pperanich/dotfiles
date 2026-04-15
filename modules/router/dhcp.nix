_: {
  flake.modules.nixos.routerDhcp =
    {
      config,
      lib,
      utils,
      ...
    }:
    let
      cfg = config.my.router;
      dhcpCfg = cfg.dhcp;
      inherit (cfg.lan) bridgeName;
      enabled = cfg.enable && dhcpCfg.enable;
    in
    {
      options.my.router.dhcp = {
        leaseTime = lib.mkOption {
          type = lib.types.int;
          default = 86400;
          description = "DHCP lease time in seconds (default 24h)";
        };
        domainName = lib.mkOption {
          type = lib.types.str;
          default = "home.arpa";
          description = "Domain name for DHCP clients (RFC 8375)";
        };
      };

      config = lib.mkIf enabled {
        services.kea = {
          # M4: Control agent bound to localhost but lacks authentication.
          ctrl-agent = {
            enable = true;
            settings = {
              http-host = "127.0.0.1";
              http-port = 8000;
            };
          };
          dhcp4 = {
            enable = true;
            settings = {
              interfaces-config = {
                # Kea does NOT listen on br-lan (the L2 trunk bridge).
                # Per-VLAN bridge interfaces are added by vlans.nix.
                # This avoids Kea's raw (PF_PACKET) socket on br-lan
                # capturing VLAN-tagged DHCP discovers before the kernel's
                # VLAN rx_handler can redirect them.
                interfaces = [ ];
                re-detect = true;
                service-sockets-max-retries = 10;
                service-sockets-retry-wait-time = 2000;
              };
              lease-database = {
                name = "/var/lib/kea/dhcp4-leases.csv";
                type = "memfile";
                persist = true;
                lfc-interval = 3600;
              };
              valid-lifetime = dhcpCfg.leaseTime;
              renew-timer = dhcpCfg.leaseTime / 2;
              rebind-timer = dhcpCfg.leaseTime * 7 / 8;
              # All DHCP subnets are created by vlans.nix (every network is a tagged VLAN)
            };
          };
        };

        systemd.services.kea-dhcp4-server =
          let
            bridgeDevice = "sys-subsystem-net-devices-${utils.escapeSystemdPath bridgeName}.device";
            # Wait for trunk bridge to have carrier (bridge member link up)
            waitForCarrier = "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --interface=${bridgeName}:carrier --timeout=30";
          in
          {
            wants = [
              "network-online.target"
              bridgeDevice
            ];
            after = [
              "systemd-networkd.service"
              "network-online.target"
              bridgeDevice
            ];
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "2s";
              ExecStartPre = waitForCarrier;
            };
          };

        # Ensure network-online waits for bridge to have carrier
        systemd.network.wait-online.extraArgs = [
          "--interface=${bridgeName}:carrier"
        ];
      };
    };
}
