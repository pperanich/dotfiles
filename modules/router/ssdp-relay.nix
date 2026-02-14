_: {
  flake.modules.nixos.routerSsdpRelay =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.features.router;
      ssdpCfg = cfg.ssdp;
      internal = cfg._internal;
      inherit (internal) lanDevice;
      enabled = cfg.enable && ssdpCfg.enable;

      # Auto-discover VLAN bridges that opted into discovery (mdns = true)
      discoveryBridges =
        if cfg.networks.enable then
          lib.mapAttrsToList (name: _: "br-${name}") (
            lib.filterAttrs (_: seg: seg.mdns && seg.vlan != null) cfg.networks.segments
          )
        else
          [ ];

      # All interfaces the relay should operate on (main LAN + discovery-enabled VLANs)
      relayInterfaces = [ lanDevice ] ++ discoveryBridges;

      # Build --dev flags for the relay command
      devFlags = lib.concatMapStringsSep " " (iface: "--dev ${iface}") relayInterfaces;
    in
    {
      options.features.router.ssdp = {
        enable = lib.mkEnableOption "SSDP relay for cross-VLAN device discovery (Chromecast, DIAL)";
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

            # Needs raw sockets for source IP spoofing
            AmbientCapabilities = [
              "CAP_NET_RAW"
              "CAP_NET_BIND_SERVICE"
            ];
          };
        };

        # Export firewall rules for injection into the main filterV4 input/forward chains.
        # Rules MUST be in the main filter table — separate nftables tables with their own
        # base chains don't override the main chain's policy drop verdict.
        features.router._internal.ssdpFirewall = {
          inputRules = lib.concatMapStringsSep "\n" (
            iface: ''iifname "${iface}" udp dport 1900 accept comment "SSDP relay ${iface}"''
          ) relayInterfaces;
          forwardRules = lib.optionalString (discoveryBridges != [ ]) (
            lib.concatMapStringsSep "\n" (
              iface:
              ''iifname "${iface}" oifname "${lanDevice}" udp sport 1900 accept comment "SSDP unicast responses ${iface}"''
            ) discoveryBridges
          );
        };
      };
    };
}
