_: {
  flake.modules.nixos.routerSsdpRelay =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.router;
      ssdpCfg = cfg.ssdp;
      inherit (cfg.lan) bridgeName;
      lanIface = cfg._internal.lanInterface or bridgeName;
      enabled = cfg.enable && ssdpCfg.enable;

      # Auto-discover VLAN segments that opted into discovery (mdns = true),
      # excluding fully isolated segments (e.g. guest).
      discoverySegments =
        if cfg.networks.enable then
          lib.filterAttrs (
            _: seg: seg.mdns && seg.vlan != null && seg.isolation != "full"
          ) cfg.networks.segments
        else
          { };

      discoveryBridges = lib.mapAttrsToList (name: _: "br-${name}") discoverySegments;

      # All interfaces the relay should operate on (main LAN + discovery-enabled VLANs)
      relayInterfaces = lib.unique ([ lanIface ] ++ discoveryBridges);

      # Build --dev flags for the relay command
      devFlags = lib.concatMapStringsSep " " (iface: "--dev ${iface}") relayInterfaces;
    in
    {
      options.my.router.ssdp = {
        enable = lib.mkEnableOption "SSDP relay for cross-VLAN device discovery (Chromecast, DIAL)";
        allowUnicastReplies = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Allow tightly-scoped SSDP unicast UDP replies (sport 1900 -> ephemeral
            1024-65535 on LAN client IPs, excluding the router) from discovery VLANs.
            Disabled by default to avoid stateless cross-VLAN UDP holes.
          '';
        };
      };

      config = lib.mkIf enabled {
        assertions = [
          {
            assertion = lib.length relayInterfaces >= 2;
            message = "router: SSDP relay requires at least 2 interfaces. Enable `mdns = true` on a VLAN network segment.";
          }
        ];

        # SSDP relay service
        systemd.services.ssdp-relay = {
          description = "SSDP Multicast Relay (UDP broadcast relay for cross-VLAN discovery)";
          after = [
            "network-online.target"
            "nftables.service"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.udp-broadcast-relay-redux}/bin/udp-broadcast-relay-redux --id 1 --port 1900 ${devFlags} --multicast 239.255.255.250";
            Restart = "on-failure";
            RestartSec = "5s";

            # Systemd sandboxing: needs raw/admin net capabilities for multicast relay & source IP spoofing
            DynamicUser = true;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectHostname = true;
            ProtectClock = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            SystemCallArchitectures = "native";
            CapabilityBoundingSet = [
              "CAP_NET_RAW"
              "CAP_NET_ADMIN"
            ];
            AmbientCapabilities = [
              "CAP_NET_RAW"
              "CAP_NET_ADMIN"
            ];
          };
        };

        # Export firewall rules for injection into the main filterV4 input/forward chains.
        # Rules MUST be in the main filter table — separate nftables tables with their own
        # base chains don't override the main chain's policy drop verdict.
        my.router._internal.ssdpFirewall = {
          inputRules = lib.concatMapStringsSep "\n" (
            iface: ''iifname "${iface}" udp dport 1900 accept comment "SSDP relay ${iface}"''
          ) relayInterfaces;
          forwardRules = lib.optionalString (ssdpCfg.allowUnicastReplies && discoverySegments != { }) (
            lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                name: seg:
                ''iifname "br-${name}" oifname "${lanIface}" ip saddr ${seg.subnet}.0/24 ip daddr ${cfg.lan.cidr} ip daddr != ${cfg.lan.address} udp sport 1900 udp dport 1024-65535 limit rate 20/second burst 40 packets accept comment "SSDP unicast responses br-${name}"''
              ) discoverySegments
            )
          );
        };
      };
    };
}
