_: {
  flake.modules.nixos.routerDns =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.router;
      dnsCfg = cfg.dns;
      internal = cfg._internal;
      inherit (internal) lanSubnet;
      inherit (internal) lanCidr;
      inherit (internal) routerIp;
      inherit (cfg.ipv6) ulaPrefix;
      inherit (cfg) machines services;
      enabled = cfg.enable && dnsCfg.enable;
    in
    {
      options.features.router.dns = {
        upstreamServers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "1.1.1.1@853#cloudflare-dns.com"
            "1.0.0.1@853#cloudflare-dns.com"
          ];
          description = "Upstream DNS servers (with DoT)";
        };
        localZone = lib.mkOption {
          type = lib.types.str;
          default = "lan.";
          description = "Local DNS zone name";
        };
      };

      config = lib.mkIf enabled {
        services.unbound = {
          enable = true;
          # DNSSEC root trust anchor (managed by NixOS module)
          enableRootTrustAnchor = true;
          settings = {
            remote-control.control-enable = true;
            server = {
              interface = [
                "127.0.0.1"
                "::1"
                routerIp
              ]
              ++ lib.optional cfg.ipv6.enable "${ulaPrefix}::1";

              access-control = [
                "127.0.0.0/8 allow"
                "::1 allow"
                "${lanCidr} allow"
              ]
              ++ lib.optional cfg.ipv6.enable "${ulaPrefix}::/64 allow"
              ++ [
                "0.0.0.0/0 refuse"
                "::0/0 refuse"
              ];

              cache-min-ttl = 0;
              cache-max-ttl = 86400;
              do-tcp = true;
              do-udp = true;
              prefetch = true;
              num-threads = 2;
              so-reuseport = true;

              # DNSSEC validation (trust anchor managed via enableRootTrustAnchor)
              val-clean-additional = true;

              # Security hardening
              hide-identity = true; # Don't reveal server identity
              hide-version = true; # Don't reveal unbound version
              harden-glue = true; # Harden against out-of-zone glue
              harden-dnssec-stripped = true; # Require DNSSEC if available
              harden-below-nxdomain = true; # RFC 8020 compliance
              # Note: harden-referral-path omitted - significant performance cost for marginal security gain
              use-caps-for-id = true; # DNS 0x20 encoding (may need disabling for incompatible servers)
              qname-minimisation = true; # QNAME minimisation (privacy)

              # Prevent DNS amplification attacks
              max-udp-size = 1232;

              # DNS Rebinding protection
              private-address = [
                "192.168.0.0/16"
                "172.16.0.0/12"
                "10.0.0.0/8"
                "fd00::/8"
                "fe80::/10"
              ];
              private-domain = [ "\"${dnsCfg.localZone}\"" ];

              # Local zone for LAN
              local-zone = "\"${dnsCfg.localZone}\" static";
              local-data = [
                "\"${cfg.hostname}.${dnsCfg.localZone} IN A ${routerIp}\""
              ]
              ++ lib.optional cfg.ipv6.enable "\"${cfg.hostname}.${dnsCfg.localZone} IN AAAA ${ulaPrefix}::1\""
              ++ map (
                machine: "\"${machine.name}.${dnsCfg.localZone} IN A ${lanSubnet}.${toString machine.ip}\""
              ) machines
              ++ map (service: "\"${service.name} IN A ${service.target}\"") services;
            };
            forward-zone = [
              {
                name = ".";
                forward-addr = dnsCfg.upstreamServers;
                forward-tls-upstream = true;
              }
            ];
          };
        };
      };
    };
}
