_: {
  flake.modules.nixos.routerDns =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.router;
      dnsCfg = cfg.dns;
      inherit (cfg.lan) address cidr;
      inherit (cfg.ipv6) ulaPrefix;
      inherit (cfg) services;
      enabled = cfg.enable && dnsCfg.enable;
      blockyEnabled = cfg.blocky.enable;

      zoneFqdn = if lib.hasSuffix "." dnsCfg.localZone then dnsCfg.localZone else "${dnsCfg.localZone}.";
      domain = lib.removeSuffix "." zoneFqdn;

      magicZoneEnabled = dnsCfg.magicDnsForwardZone.enable;
      magicZoneFqdn =
        if lib.hasSuffix "." dnsCfg.magicDnsForwardZone.zone then
          dnsCfg.magicDnsForwardZone.zone
        else
          "${dnsCfg.magicDnsForwardZone.zone}.";

      staticHostRecords = map (r: {
        fqdn = "${r.hostname}.${domain}";
        inherit (r) ip;
      }) (cfg._internal.staticHostReservations or [ ]);
    in
    {
      options.my.router.dns = {
        upstreamServers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "1.1.1.1@853#cloudflare-dns.com"
            "1.0.0.1@853#cloudflare-dns.com"
            "9.9.9.9@853#dns.quad9.net"
            "149.112.112.112@853#dns.quad9.net"
          ];
          description = "Upstream DNS-over-TLS servers (multiple providers for redundancy)";
        };
        localZone = lib.mkOption {
          type = lib.types.str;
          default = "home.arpa.";
          description = "Local DNS zone name (RFC 8375)";
        };
        privateDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "prestonperanich.com" ];
          description = "Domains exempt from DNS rebinding protection (allowed to resolve to private IPs)";
        };
        extraInterfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "fdb4:63fa:2:aa00::1" ];
          description = "Additional addresses for DNS to listen on (e.g., VPN interfaces). Configures Blocky when enabled, otherwise Unbound.";
        };
        extraAccessControl = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "fdb4:63fa:2:aa00::/40 allow" ];
          description = "Additional access-control entries for Unbound (e.g., VPN subnets). Used by Unbound when Blocky is disabled.";
        };
        extraLocalData = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "pp-wsl1.home.arpa. CNAME pperanich-wd1.home.arpa." ];
          description = "Additional local-data entries for Unbound (e.g., CNAME aliases)";
        };
        extraLocalZones = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "\"_acme-challenge.pages.example.com.\" transparent"
            "\"pages.example.com.\" redirect"
          ];
          description = "Additional local-zone entries for Unbound (e.g., wildcard redirect zones and transparent carve-outs)";
        };
        magicDnsForwardZone = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = (config.my.headscale.enable or false) || (config.services.tailscale.enable or false);
            defaultText = lib.literalExpression "(config.my.headscale.enable or false) || (config.services.tailscale.enable or false)";
            description = "Delegate the Tailscale MagicDNS zone (`pp-ts.`) to local tailscaled (`100.100.100.100`).";
          };
          zone = lib.mkOption {
            type = lib.types.str;
            default = "${config.my.headscale.baseDomain or (config.my.tailscale.magicDnsSuffix or "pp-ts")}.";
            defaultText = lib.literalExpression ''"''${config.my.headscale.baseDomain or "pp-ts"}."'';
            description = "MagicDNS zone FQDN delegated to local tailscaled.";
          };
          forwardAddr = lib.mkOption {
            type = lib.types.str;
            default = "100.100.100.100";
            description = "Local Tailscale Quad100 resolver address.";
          };
        };
      };

      config = lib.mkIf enabled {
        services.unbound = {
          enable = true;
          # DNSSEC root trust anchor (managed by NixOS module)
          enableRootTrustAnchor = true;
          settings = {
            remote-control.control-enable = true;
            server =
              let
                # VLAN IPs for Unbound-only fallback (moved from vlans.nix)
                vlanNets = lib.filterAttrs (_: n: (n.vlan or null) != null) (cfg._internal.networks or { });
                vlanIps = lib.mapAttrsToList (_: net: net.routerIp) vlanNets;
                vlanAcls = lib.mapAttrsToList (_: net: "${net.cidr} allow") vlanNets;
              in
              {
                # When Blocky is enabled, Unbound retreats to localhost:5335 as a backend.
                # Blocky takes over port 53 on all LAN, VLAN and tailnet interfaces.
                port = if blockyEnabled then 5335 else 53;

                interface =
                  if blockyEnabled then
                    [
                      "127.0.0.1"
                      "::1"
                    ]
                  else
                    [
                      "127.0.0.1"
                      "::1"
                      address
                    ]
                    ++ lib.optional cfg.ipv6.enable "${ulaPrefix}::1"
                    ++ dnsCfg.extraInterfaces
                    ++ vlanIps;

                access-control =
                  if blockyEnabled then
                    [
                      "127.0.0.0/8 allow"
                      "::1 allow"
                      "0.0.0.0/0 refuse"
                      "::0/0 refuse"
                    ]
                  else
                    [
                      "127.0.0.0/8 allow"
                      "::1 allow"
                      "${cidr} allow"
                    ]
                    ++ lib.optional cfg.ipv6.enable "${ulaPrefix}::/64 allow"
                    ++ dnsCfg.extraAccessControl
                    ++ vlanAcls
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
                private-domain = [
                  "\"${dnsCfg.localZone}\""
                ]
                ++ map (d: "\"${d}\"") dnsCfg.privateDomains
                ++ lib.optional magicZoneEnabled "\"${magicZoneFqdn}\"";
                domain-insecure = lib.optional magicZoneEnabled "\"${magicZoneFqdn}\"";

                # Local zone for LAN
                local-zone = [
                  "\"${zoneFqdn}\" static"
                ]
                ++ lib.optional magicZoneEnabled "\"${magicZoneFqdn}\" transparent"
                ++ dnsCfg.extraLocalZones;

                local-data =
                  let
                    extractOwner =
                      raw:
                      let
                        tok = builtins.head (lib.splitString " " (lib.trim raw));
                      in
                      lib.removeSuffix "." (lib.toLower tok);

                    explicitOwners =
                      map extractOwner dnsCfg.extraLocalData
                      ++ map (s: lib.removeSuffix "." (lib.toLower s.name)) services;

                    routerHostnames = lib.unique [
                      (lib.toLower cfg.hostname)
                      (lib.toLower config.networking.hostName)
                    ];

                    staticCandidates =
                      (map (h: {
                        fqdn = "${h}.${domain}";
                        ip = address;
                      }) routerHostnames)
                      ++ staticHostRecords
                      ++ (map
                        (alias: {
                          fqdn = "${alias}.${domain}";
                          ip = address;
                        })
                        [
                          "router"
                          "gateway"
                          "unifi"
                        ]
                      );

                    dedupByFqdn =
                      builtins.foldl'
                        (
                          acc: item:
                          if builtins.elem item.fqdn acc.seen || builtins.elem item.fqdn explicitOwners then
                            acc
                          else
                            {
                              seen = acc.seen ++ [ item.fqdn ];
                              items = acc.items ++ [ item ];
                            }
                        )
                        {
                          seen = [ ];
                          items = [ ];
                        }
                        staticCandidates;
                  in
                  (map (item: "\"${item.fqdn}. IN A ${item.ip}\"") dedupByFqdn.items)
                  ++ lib.optional (
                    cfg.ipv6.enable && !(builtins.elem "${lib.toLower cfg.hostname}.${domain}" explicitOwners)
                  ) "\"${lib.toLower cfg.hostname}.${zoneFqdn} IN AAAA ${ulaPrefix}::1\""
                  ++ map (service: "\"${service.name} IN A ${service.target}\"") services
                  ++ map (d: "\"${d}\"") dnsCfg.extraLocalData;

                local-data-ptr =
                  let
                    ptrCandidates = [
                      {
                        ip = address;
                        fqdn = "${lib.toLower cfg.hostname}.${domain}";
                      }
                    ]
                    ++ lib.optional cfg.ipv6.enable {
                      ip = "${ulaPrefix}::1";
                      fqdn = "${lib.toLower cfg.hostname}.${domain}";
                    }
                    ++ staticHostRecords;

                    dedupByIp =
                      builtins.foldl'
                        (
                          acc: item:
                          if builtins.elem item.ip acc.seen then
                            acc
                          else
                            {
                              seen = acc.seen ++ [ item.ip ];
                              items = acc.items ++ [ item ];
                            }
                        )
                        {
                          seen = [ ];
                          items = [ ];
                        }
                        ptrCandidates;
                  in
                  map (item: "\"${item.ip} ${item.fqdn}\"") dedupByIp.items;
              };
            forward-zone =
              lib.optional magicZoneEnabled {
                name = magicZoneFqdn;
                forward-addr = [ dnsCfg.magicDnsForwardZone.forwardAddr ];
              }
              ++ [
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
