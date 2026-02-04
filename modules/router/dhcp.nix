_: {
  flake.modules.nixos.routerDhcp =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      cfg = config.features.router;
      dhcpCfg = cfg.dhcp;
      internal = cfg._internal;
      inherit (internal) lanSubnet;
      inherit (internal) lanCidr;
      inherit (internal) routerIp;
      inherit (internal) dhcpStart;
      inherit (internal) dhcpEnd;
      inherit (internal) lanDevice;
      inherit (cfg) machines;
      enabled = cfg.enable && dhcpCfg.enable;
    in
    {
      options.features.router.dhcp = {
        leaseTime = lib.mkOption {
          type = lib.types.int;
          default = 86400;
          description = "DHCP lease time in seconds (default 24h)";
        };
        domainName = lib.mkOption {
          type = lib.types.str;
          default = "lan";
          description = "Domain name for DHCP clients";
        };
      };

      config = lib.mkIf enabled {
        services.kea = {
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
                interfaces = [ lanDevice ];
                re-detect = true;
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
                  subnet = lanCidr;
                  pools = [ { pool = "${dhcpStart} - ${dhcpEnd}"; } ];
                  reservations = map (machine: {
                    hw-address = machine.mac;
                    ip-address = "${lanSubnet}.${toString machine.ip}";
                    hostname = machine.name;
                  }) machines;
                  option-data = [
                    {
                      name = "routers";
                      data = routerIp;
                    }
                    {
                      name = "domain-name-servers";
                      data = routerIp;
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
            bridgeDevice = "sys-subsystem-net-devices-${utils.escapeSystemdPath lanDevice}.device";
            # Wait for interface to have an IP address (not just exist)
            waitForIp = pkgs.writeShellScript "wait-for-dhcp-interface" ''
              set -euo pipefail
              max_attempts=30
              attempt=0
              while [ $attempt -lt $max_attempts ]; do
                if ${pkgs.iproute2}/bin/ip addr show ${lanDevice} 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "inet "; then
                  echo "Interface ${lanDevice} has IP, proceeding"
                  exit 0
                fi
                attempt=$((attempt + 1))
                echo "Waiting for ${lanDevice} to get IP (attempt $attempt/$max_attempts)..."
                sleep 1
              done
              echo "ERROR: ${lanDevice} did not get IP after $max_attempts seconds"
              exit 1
            '';
          in
          {
            wants = [
              "network-online.target"
              bridgeDevice
            ];
            after = [
              "systemd-networkd.service"
              "network-online.target"
              bridgeDevice # Wait for bridge interface
            ];
            # Note: Don't use bindsTo with device units - too fragile during reconfigs
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "2s";
              # Wait for interface to have IP before starting Kea
              ExecStartPre = waitForIp;
            };
          };

        # Ensure network-online waits for bridge to have carrier
        systemd.network.wait-online.extraArgs = [
          "--interface=${lanDevice}:carrier"
        ];
      };
    };
}
