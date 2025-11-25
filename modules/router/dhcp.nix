_: {
  flake.modules.nixos.routerDhcp =
    {
      config,
      lib,
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

        systemd.services.kea-dhcp4-server = {
          wants = [ "network-online.target" ];
          after = [
            "systemd-networkd.service"
            "network-online.target"
          ];
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
      };
    };
}
