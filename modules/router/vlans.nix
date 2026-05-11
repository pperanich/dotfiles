_: {
  flake.modules.nixos.routerVlans =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.router;
      netCfg = cfg.networks;
      wan = cfg.wan.interface;
      inherit (cfg.lan) bridgeName;
      enabled = cfg.enable && netCfg.enable;

      # Convert networks attrset to list with names
      networkList = lib.mapAttrsToList (name: net: net // { inherit name; }) netCfg.segments;

      # The primary LAN L3 interface — the per-VLAN bridge for the network
      # matching the main LAN subnet (cfg.lan.subnet).
      lanInterface =
        let
          mainSeg = lib.findFirst (n: n.subnet == cfg.lan.subnet) null networkList;
        in
        if mainSeg != null then "br-${mainSeg.name}" else bridgeName;

      # Every network gets its own bridge: br-${name}
      netIfaceName = net: "br-${net.name}";
      netBridge = net: "br-${net.name}";

      # Get router IP for a network
      netRouterIp = net: "${net.subnet}.1";

      # Get CIDR for a network
      netCidr = net: "${net.subnet}.0/24";

      # Veth pair names for connecting br-lan (trunk) to per-VLAN bridges.
      # Using veth pairs instead of VLAN subinterfaces because VLAN-aware
      # bridge egress untagging doesn't work for frames injected via VLAN
      # subinterface tx handlers — the bridge sends them out still tagged.
      netVethTrunk = net: "v-${net.name}"; # end in br-lan
      netVethBridge = net: "v-${net.name}-br"; # end in br-${name}

      # Build input rules (services on router)
      mkInputRules =
        net:
        let
          iface = netIfaceName net;
        in
        ''
          # Network ${net.name}: Router services (INPUT)
          iifname "${iface}" udp dport 67 accept comment "DHCP ${net.name}"
          iifname "${iface}" tcp dport 53 accept comment "DNS TCP ${net.name}"
          iifname "${iface}" udp dport 53 accept comment "DNS UDP ${net.name}"
          iifname "${iface}" udp dport 123 accept comment "NTP ${net.name}"
          iifname "${iface}" icmp type { echo-request, destination-unreachable, time-exceeded, parameter-problem } accept comment "ICMP ${net.name}"
          ${lib.optionalString (net.isolation == "none") ''
            iifname "${iface}" tcp dport 22 accept comment "SSH from ${net.name}"
            iifname "${iface}" tcp dport 3000 accept comment "ntopng from ${net.name}"
          ''}
        '';

      # Build forward rules
      mkForwardRules =
        net:
        let
          iface = netIfaceName net;
          networksByName = lib.listToAttrs (map (n: lib.nameValuePair n.name n) networkList);

          # Get interfaces this network can access
          allowedToIfaces = map (name: netIfaceName networksByName.${name}) net.allowAccessTo;

          # Get interfaces that can access this network
          allowedFromIfaces = map (name: netIfaceName networksByName.${name}) net.allowAccessFrom;
        in
        if net.isolation == "none" then
          ''
            # ${net.name}: Trusted - full access to WAN and all networks
            iifname "${iface}" oifname "${wan}" accept comment "${net.name} to WAN"
            ${lib.concatMapStringsSep "\n" (
              n:
              lib.optionalString (n.name != net.name) ''
                iifname "${iface}" oifname "${netIfaceName n}" accept comment "${net.name} to ${n.name}"
              ''
            ) networkList}
          ''
        else if net.isolation == "internet" then
          ''
            # ${net.name}: Internet + explicit allows only
            iifname "${iface}" oifname "${wan}" accept comment "${net.name} to WAN"
            ${lib.concatMapStringsSep "\n" (
              toIface: ''iifname "${iface}" oifname "${toIface}" accept comment "${net.name} explicit access"''
            ) allowedToIfaces}
            ${lib.concatMapStringsSep "\n" (
              fromIface: ''iifname "${fromIface}" oifname "${iface}" accept comment "Access to ${net.name}"''
            ) allowedFromIfaces}
          ''
        else
          ''
            # ${net.name}: Full isolation - internet only
            iifname "${iface}" oifname "${wan}" accept comment "${net.name} to WAN"
          '';

      # Collected rules for firewall
      allInputRules = lib.concatMapStringsSep "\n" mkInputRules networkList;
      allForwardRules = lib.concatMapStringsSep "\n" mkForwardRules networkList;
      allNatRules = lib.concatMapStringsSep "\n" (
        net: ''oifname "${wan}" ip saddr ${netCidr net} masquerade comment "NAT ${net.name}"''
      ) networkList;
    in
    {
      options.my.router.networks = {
        enable = lib.mkEnableOption "unified network segment definitions";

        segments = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule (_: {
              options = {
                vlan = lib.mkOption {
                  type = lib.types.ints.between 1 4094;
                  example = 20;
                  description = "VLAN ID (1-4094). All segments must be tagged.";
                };

                subnet = lib.mkOption {
                  type = lib.types.strMatching "^[0-9]+\\.[0-9]+\\.[0-9]+$";
                  example = "10.0.20";
                  description = "Subnet base (first 3 octets, e.g., '10.0.20')";
                };

                dhcpRange = {
                  start = lib.mkOption {
                    type = lib.types.ints.between 2 254;
                    default = 100;
                    description = "DHCP range start (last octet)";
                  };
                  end = lib.mkOption {
                    type = lib.types.ints.between 2 254;
                    default = 200;
                    description = "DHCP range end (last octet)";
                  };
                };

                isolation = lib.mkOption {
                  type = lib.types.enum [
                    "none"
                    "internet"
                    "full"
                  ];
                  default = "internet";
                  description = ''
                    Network isolation level:
                    - none: Full access to all networks (trusted)
                    - internet: Internet access only + explicit allows
                    - full: Internet only, no inter-network access
                  '';
                };

                allowAccessFrom = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  example = [ "main" ];
                  description = "Other networks that can initiate connections to this one";
                };

                allowAccessTo = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  example = [ "iot" ];
                  description = "Networks this one can initiate connections to";
                };

                mdns = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Enable mDNS/service discovery on this network segment.
                    Allows devices on this VLAN to be discovered via AirPlay, Chromecast, etc.
                  '';
                };

                reservations = lib.mkOption {
                  type = lib.types.listOf (
                    lib.types.submodule {
                      options = {
                        hostname = lib.mkOption {
                          type = lib.types.strMatching "^[a-zA-Z0-9-]+$";
                          description = "Hostname for DHCP/DDNS registration (no domain).";
                        };
                        mac = lib.mkOption {
                          type = lib.types.strMatching "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$";
                          description = "Client MAC address (XX:XX:XX:XX:XX:XX).";
                        };
                        ip = lib.mkOption {
                          type = lib.types.ints.between 2 254;
                          description = "Reserved IP (last octet only — combined with segment subnet).";
                        };
                      };
                    }
                  );
                  default = [ ];
                  example = lib.literalExpression ''
                    [ { hostname = "pp-printer1"; mac = "f8:a2:6d:00:6c:b2"; ip = 50; } ]
                  '';
                  description = "Kea DHCPv4 host reservations for this segment (MAC → fixed IP + hostname).";
                };
              };
            })
          );
          default = { };
          description = "Network segment definitions. All segments must have a VLAN tag.";
        };
      };

      config = lib.mkIf enabled {
        # Validation assertions
        assertions =
          let
            vlanIds = map (n: n.vlan) networkList;
            subnets = map (n: n.subnet) networkList;
          in
          # Check dhcpRange validity
          (map (net: {
            assertion = net.dhcpRange.start < net.dhcpRange.end;
            message = "Network ${net.name}: dhcpRange.start must be less than end";
          }) networkList)
          ++
            # Check allowAccessTo references valid networks
            (lib.concatMap (
              net:
              map (ref: {
                assertion = lib.hasAttr ref netCfg.segments;
                message = "Network ${net.name}: allowAccessTo references unknown network '${ref}'";
              }) net.allowAccessTo
            ) networkList)
          ++
            # Check allowAccessFrom references valid networks
            (lib.concatMap (
              net:
              map (ref: {
                assertion = lib.hasAttr ref netCfg.segments;
                message = "Network ${net.name}: allowAccessFrom references unknown network '${ref}'";
              }) net.allowAccessFrom
            ) networkList)
          ++
            # Prevent self-references in allowAccessTo
            (lib.concatMap (
              net:
              map (ref: {
                assertion = ref != net.name;
                message = "Network ${net.name}: cannot reference itself in allowAccessTo";
              }) net.allowAccessTo
            ) networkList)
          ++
            # Prevent self-references in allowAccessFrom
            (lib.concatMap (
              net:
              map (ref: {
                assertion = ref != net.name;
                message = "Network ${net.name}: cannot reference itself in allowAccessFrom";
              }) net.allowAccessFrom
            ) networkList)
          ++
            # Reservation IPs must be within 2-254 of the subnet (already constrained by type),
            # not collide with router (.1), and unique per segment.
            (lib.concatMap (
              net:
              [
                {
                  assertion =
                    let
                      ips = map (r: r.ip) net.reservations;
                    in
                    ips == lib.unique ips;
                  message = "Network ${net.name}: duplicate reservation IPs";
                }
                {
                  assertion =
                    let
                      macs = map (r: lib.toLower r.mac) net.reservations;
                    in
                    macs == lib.unique macs;
                  message = "Network ${net.name}: duplicate reservation MAC addresses";
                }
              ]
              ++ map (r: {
                assertion = r.ip != 1;
                message = "Network ${net.name}: reservation '${r.hostname}' cannot use .1 (reserved for router)";
              }) net.reservations
            ) networkList)
          ++ [
            # Unique VLAN IDs
            {
              assertion = lib.length vlanIds == lib.length (lib.unique vlanIds);
              message = "Network VLAN IDs must be unique";
            }
            # Unique subnets
            {
              assertion = lib.length subnets == lib.length (lib.unique subnets);
              message = "Network subnets must be unique";
            }
          ];

        # Export computed values for other modules
        my.router._internal.lanInterface = lanInterface;

        # Export network info for other modules
        my.router._internal.networks = lib.listToAttrs (
          map (net: {
            inherit (net) name;
            value = {
              inherit (net) vlan subnet isolation;
              interface = netIfaceName net;
              routerIp = netRouterIp net;
              cidr = netCidr net;
              bridge = netBridge net;
            };
          }) networkList
        );

        # Export firewall rules (always export, even if empty, for proper fallback handling)
        my.router._internal.networkFirewall = {
          inputRules = if networkList != [ ] then allInputRules else "";
          forwardRules =
            if networkList != [ ] then
              ''
                # Network-specific forwarding rules
                ${allForwardRules}
              ''
            else
              "";
          natRules = if networkList != [ ] then allNatRules else "";
        };

        # br-lan is a pure L2 trunk bridge with VLAN filtering — no IP address.
        # All L3 lives on per-VLAN bridges (br-main, br-iot, br-guest), each
        # connected to br-lan via a veth pair. This prevents Kea's raw
        # (PF_PACKET) socket from seeing DHCP discovers for other VLANs.
        #
        # We use veth pairs (not VLAN subinterfaces) because a VLAN-aware
        # bridge's egress untagging does not apply to frames injected via a
        # VLAN subinterface's tx handler — they exit physical ports still
        # tagged, breaking untagged clients. Veth ports are real bridge
        # ports with proper VLAN filtering and egress untagging support.
        systemd.network = lib.mkIf (networkList != [ ]) {
          netdevs =
            # Enable VLAN filtering on br-lan trunk bridge
            {
              "20-br-lan" = {
                bridgeConfig.VLANFiltering = true;
              };
            }
            //
              # Veth pair for each VLAN: one end in br-lan, other in br-${name}
              lib.listToAttrs (
                map (net: {
                  name = "40-veth-${net.name}";
                  value = {
                    netdevConfig = {
                      Kind = "veth";
                      Name = netVethTrunk net;
                    };
                    peerConfig = {
                      Name = netVethBridge net;
                    };
                  };
                }) networkList
              )
            //
              # Bridge for each VLAN network
              lib.listToAttrs (
                map (net: {
                  name = "30-br-${net.name}";
                  value = {
                    netdevConfig = {
                      Kind = "bridge";
                      Name = netBridge net;
                    };
                    # Disable IGMP snooping on discovery-enabled bridges so reflected
                    # mDNS/SSDP multicast floods to all ports.
                    bridgeConfig = lib.mkIf net.mdns {
                      MulticastSnooping = false;
                    };
                  };
                }) networkList
              );

          networks =
            # Trunk bridge: no IP, no IPv6 RA/PD
            {
              "10-lan" = {
                address = lib.mkForce [ ];
                networkConfig = {
                  IPv6SendRA = lib.mkForce false;
                  DHCPPrefixDelegation = lib.mkForce false;
                };
                ipv6Prefixes = lib.mkForce [ ];
              };
            }
            //
              # Bridge VLAN membership per physical trunk port.
              #
              # Every segment's VLAN is registered on every LAN port so any
              # port can carry any VLAN. The segment whose `subnet` equals
              # `cfg.lan.subnet` is treated as the **native / untagged** VLAN:
              # it gets `PVID` (untagged ingress inferred as this VLAN) and
              # `EgressUntagged` (frames leave the port without an 802.1Q tag).
              # Other segments are tagged-only — VLAN registered, no PVID, no
              # untagged egress.
              #
              # The native VLAN is still logically tagged inside the router
              # (used for Kea server-id derivation, segment isolation rules,
              # veth trunk membership) — only the wire is untagged.
              #
              # Downstream AP must match this asymmetry:
              #   - SSIDs for the native segment → AP "untagged" network
              #     (UniFi: bind SSID to the "Default" network, NOT to a
              #     `vlan-only` network with the matching VLAN ID — AP would
              #     then tag frames and mismatch router's untagged egress,
              #     breaking wired→Wi-Fi multicast for that SSID).
              #   - SSIDs for other segments → AP tagged network with VID.
              lib.listToAttrs (
                map (iface: {
                  name = "30-${iface}-lan";
                  value = {
                    bridgeVLANs = map (
                      net:
                      {
                        VLAN = net.vlan;
                      }
                      // lib.optionalAttrs (net.subnet == cfg.lan.subnet) {
                        PVID = net.vlan;
                        EgressUntagged = net.vlan;
                      }
                    ) networkList;
                  };
                }) cfg.lan.interfaces
              )
            //
              # Veth trunk end: bridge into br-lan with single-VLAN membership
              lib.listToAttrs (
                map (net: {
                  name = "41-veth-${net.name}-trunk";
                  value = {
                    matchConfig.Name = netVethTrunk net;
                    networkConfig = {
                      Bridge = bridgeName;
                      ConfigureWithoutCarrier = true;
                    };
                    bridgeVLANs = [
                      {
                        VLAN = net.vlan;
                        PVID = net.vlan;
                        EgressUntagged = net.vlan;
                      }
                    ];
                  };
                }) networkList
              )
            //
              # Veth bridge end: bridge into per-VLAN bridge
              lib.listToAttrs (
                map (net: {
                  name = "42-veth-${net.name}-bridge";
                  value = {
                    matchConfig.Name = netVethBridge net;
                    networkConfig = {
                      Bridge = netBridge net;
                      ConfigureWithoutCarrier = true;
                    };
                  };
                }) networkList
              )
            //
              # Configure each VLAN bridge with IP address.
              # The main LAN bridge also gets IPv6 (ULA, RA, DHCPv6-PD).
              lib.listToAttrs (
                map (
                  net:
                  let
                    isMain = net.subnet == cfg.lan.subnet;
                    inherit (cfg.ipv6) ulaPrefix;
                  in
                  {
                    name = "50-br-${net.name}";
                    value = {
                      matchConfig.Name = netBridge net;
                      address = [
                        "${netRouterIp net}/24"
                      ]
                      ++ lib.optional (isMain && cfg.ipv6.enable) "${ulaPrefix}::1/64";
                      networkConfig = {
                        ConfigureWithoutCarrier = true;
                      }
                      // lib.optionalAttrs isMain {
                        DHCPPrefixDelegation = cfg.ipv6.enable;
                        IPv6SendRA = cfg.ipv6.enable;
                        IPv6AcceptRA = false;
                      };
                      ipv6Prefixes = lib.mkIf (isMain && cfg.ipv6.enable) [
                        {
                          AddressAutoconfiguration = true;
                          OnLink = true;
                          Prefix = "${ulaPrefix}::/64";
                        }
                      ];
                    };
                  }
                ) networkList
              );
        };

        # DHCP: Kea listens on per-VLAN bridge interfaces (not br-lan)
        services.kea.dhcp4.settings.interfaces-config.interfaces = lib.mkIf (networkList != [ ]) (
          map netBridge networkList
        );

        # DHCP pools for all networks
        services.kea.dhcp4.settings.subnet4 = lib.mkIf (networkList != [ ]) (
          map (net: {
            id = 1000 + net.vlan;
            subnet = netCidr net;
            interface = netBridge net;
            pools = [
              {
                pool = "${net.subnet}.${toString net.dhcpRange.start} - ${net.subnet}.${toString net.dhcpRange.end}";
              }
            ];
            option-data = [
              {
                name = "routers";
                data = netRouterIp net;
              }
              {
                name = "domain-name-servers";
                data = netRouterIp net;
              }
              {
                name = "domain-name";
                data = "${net.name}.${cfg.dhcp.domainName}";
              }
            ];
            reservations = map (r: {
              hw-address = lib.toLower r.mac;
              ip-address = "${net.subnet}.${toString r.ip}";
              hostname = r.hostname;
            }) net.reservations;
          }) networkList
        );

        # DNS: VLAN listener config handled by dns.nix (Unbound) and blocky.nix (Blocky)
        # via _internal.networks — see routerDns and routerBlocky modules

        # Chrony: Allow NTP from all networks
        services.chrony.extraConfig = lib.mkIf (networkList != [ ]) (
          lib.concatMapStringsSep "\n" (net: "allow ${netCidr net}") networkList
        );
      };
    };
}
