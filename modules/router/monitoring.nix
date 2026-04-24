_: {
  flake.modules.nixos.routerMonitoring =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.router;
      monCfg = cfg.monitoring;
      inherit (cfg.lan) bridgeName;
      lanIface = cfg._internal.lanInterface or bridgeName;
      enabled = cfg.enable && monCfg.enable;

      # Build list of interfaces to monitor
      monitorInterfaces =
        if monCfg.interfaces != [ ] then
          monCfg.interfaces
        else
          # Default: monitor trunk bridge + WAN (+ main LAN bridge if separate)
          [
            bridgeName
            cfg.wan.interface
          ]
          ++ lib.optional (lanIface != bridgeName) lanIface;
    in
    {
      options.my.router.monitoring = {
        enable = lib.mkEnableOption "network monitoring with ntopng";

        httpPort = lib.mkOption {
          type = lib.types.port;
          default = 3000;
          description = "Port for ntopng web interface";
        };

        interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "br-lan"
            "eth0"
          ];
          description = ''
            Interfaces to monitor. Empty list means auto-detect
            (LAN bridge and WAN).
          '';
        };

        localNetworks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "${cfg.lan.subnet}.0/24" ];
          description = "Local networks for ntopng to recognize as internal";
        };

        dnsMode = lib.mkOption {
          type = lib.types.enum [
            0
            1
            2
            3
          ];
          default = 1;
          description = ''
            DNS resolution mode:
            0 - Decode DNS and resolve local IPs only
            1 - Decode DNS and resolve all IPs
            2 - Decode DNS but don't resolve
            3 - Don't decode DNS/MDNS/HTTP/TLS
          '';
        };

        retentionDays = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Days to retain flow data";
        };
      };

      config = lib.mkIf enabled {
        # Export firewall rules for injection into firewall.nix
        my.router._internal.monitoringFirewall = {
          inputRules = ''
            # ntopng web UI - LAN only
            iifname "${lanIface}" tcp dport ${toString monCfg.httpPort} accept comment "ntopng web UI"
          '';
        };

        # ntopng for traffic analysis
        services.ntopng = {
          enable = true;
          inherit (monCfg) httpPort;
          interfaces = monitorInterfaces;
          redis.createInstance = "ntopng";

          extraConfig = ''
            # Local networks (recognized as internal traffic)
            ${lib.concatMapStringsSep "\n" (net: "--local-networks=${net}") monCfg.localNetworks}

            # DNS resolution mode
            --dns-mode=${toString monCfg.dnsMode}

            # Data retention
            --data-retention=${toString monCfg.retentionDays}

            # Disable login for LAN access (optional, can be changed)
            # --disable-login=1

            # Community edition optimizations
            --max-num-flows=200000
            --max-num-hosts=65535

            # Enable local traffic analysis
            --local-host-cache-duration=86400

            # Don't send usage stats
            --no-usage-stats
          '';
        };

        # Ensure ntopng user can capture packets
        users.users.ntopng.extraGroups = [ "networkd" ];

        # Add packet capture capability
        # M5: Only cap_net_raw is needed for packet capture — cap_net_admin omitted
        # to prevent firewall/routing modification if ntopng is compromised
        security.wrappers.ntopng = {
          owner = "root";
          group = "ntopng";
          capabilities = "cap_net_raw+eip";
          source = "${pkgs.ntopng}/bin/ntopng";
        };

        # Monitoring tools
        environment.systemPackages = with pkgs; [
          ntopng
          tcpdump
          iftop
          nethogs
        ];
      };
    };
}
