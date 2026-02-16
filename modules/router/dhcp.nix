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
      inherit (cfg._internal) dhcpStart dhcpEnd;
      inherit (cfg.lan)
        address
        cidr
        subnet
        bridgeName
        ;
      inherit (cfg) machines;
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
          # Any local process can issue Kea commands (modify leases, change config).
          # Consider adding basic auth via settings.authentication if running
          # untrusted services on this host, or disable if not needed.
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
                interfaces = [ bridgeName ];
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
              subnet4 = [
                {
                  id = 1;
                  subnet = cidr;
                  pools = [ { pool = "${dhcpStart} - ${dhcpEnd}"; } ];
                  reservations = map (machine: {
                    hw-address = machine.mac;
                    ip-address = "${subnet}.${toString machine.ip}";
                    hostname = machine.name;
                  }) machines;
                  option-data = [
                    {
                      name = "routers";
                      data = address;
                    }
                    {
                      name = "domain-name-servers";
                      data = address;
                    }
                    {
                      name = "domain-name";
                      data = dhcpCfg.domainName;
                    }
                  ];
                }
              ];
            };
          };
        };

        systemd.services.kea-dhcp4-server =
          let
            bridgeDevice = "sys-subsystem-net-devices-${utils.escapeSystemdPath bridgeName}.device";
            # Wait for bridge to have carrier using netlink events (no polling).
            # br-lan gets its IP immediately via ConfigureWithoutCarrier, but Kea
            # needs the interface to be RUNNING (have carrier from a bridge member).
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
