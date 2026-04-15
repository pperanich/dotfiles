_: {
  flake.modules.nixos.routerMdns =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.router;
      mdnsCfg = cfg.mdns;
      inherit (cfg.lan) bridgeName;
      lanIface = cfg._internal.lanInterface or bridgeName;
      enabled = cfg.enable && mdnsCfg.enable;

      # VLAN bridges that opted into mDNS via per-segment `mdns = true`
      mdnsNetworkBridges =
        if cfg.networks.enable then
          lib.mapAttrsToList (name: _: "br-${name}") (
            lib.filterAttrs (_: seg: seg.mdns && seg.vlan != null) cfg.networks.segments
          )
        else
          [ ];

      # Build list of interfaces to allow mDNS on
      mdnsInterfaces = [
        lanIface
      ]
      ++ mdnsNetworkBridges
      ++ mdnsCfg.extraInterfaces;
    in
    {
      options.my.router.mdns = {
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
        # L4: Prevent mDNS reflector from leaking service discovery across isolated VLANs
        assertions = lib.optional cfg.networks.enable {
          assertion = builtins.all (
            iface:
            let
              segName = lib.removePrefix "br-" iface;
            in
            !(
              lib.hasPrefix "br-" iface
              && lib.hasAttr segName cfg.networks.segments
              && cfg.networks.segments.${segName}.isolation != "none"
            )
          ) mdnsCfg.extraInterfaces;
          message = "router: mDNS extraInterfaces must not include isolated VLAN bridges — this would leak service discovery across security boundaries";
        };

        # Export firewall rules for injection into the main filterV4/filterV6 input chains.
        # mDNS rules MUST be in the main filter tables — separate nftables tables with
        # their own base chains don't override the main chain's policy drop verdict.
        # In nftables, every base chain on the same hook evaluates independently and
        # ALL must accept for a packet to pass.
        my.router._internal.mdnsFirewall = {
          inputRules = lib.concatMapStringsSep "\n" (
            iface: ''iifname "${iface}" udp dport 5353 accept comment "mDNS ${iface}"''
          ) mdnsInterfaces;
          inputRulesV6 = lib.concatMapStringsSep "\n" (
            iface: ''iifname "${iface}" udp dport 5353 accept comment "mDNS IPv6 ${iface}"''
          ) mdnsInterfaces;
        };

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
      };
    };
}
