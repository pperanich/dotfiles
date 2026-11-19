_: {
  flake.modules.nixos.routerFirewall =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.router;
      fwCfg = cfg.firewall;
      networksCfg = cfg.networks;
      internal = cfg._internal;
      inherit (cfg.lan) subnet bridgeName;
      wan = cfg.wan.interface;

      # L3 interface for the main LAN (per-VLAN bridge, e.g. br-main).
      # bridgeName is the L2 trunk bridge (br-lan) — no L3 services.
      lanIface = internal.lanInterface or bridgeName;

      # Get network firewall rules (from networks.nix)
      netFw =
        internal.networkFirewall or {
          inputRules = "";
          forwardRules = "";
          natRules = "";
        };

      # Get mDNS firewall rules if mDNS is enabled
      mdnsFw =
        internal.mdnsFirewall or {
          inputRules = "";
          inputRulesV6 = "";
        };

      # Get monitoring firewall rules if monitoring is enabled
      monFw =
        internal.monitoringFirewall or {
          inputRules = "";
        };

      # Get SSDP relay firewall rules if enabled
      ssdpFw =
        internal.ssdpFirewall or {
          inputRules = "";
          forwardRules = "";
        };

      # Get Unifi controller firewall rules if enabled
      unifiFw =
        internal.unifiFirewall or {
          inputRules = "";
        };

      # Get Unifi controller interfaces if available
      unifiControllerInterfaces = internal.unifiControllerInterfaces or [ ];

      # Debug uplink is NOT added to trusted interfaces: gets SSH-only access instead
      allTrustedInterfaces = fwCfg.trustedInterfaces;

      # Helper to generate an nftables named set of interface names
      mkIfaceSet = name: interfaces: ''
        set ${name} {
          typeof iifname
          elements = { ${lib.concatMapStringsSep ", " (i: ''"${i}"'') interfaces} }
        }
      '';

      # Build open ports rules
      tcpPortsStr = lib.concatMapStringsSep ", " toString fwCfg.openPorts.tcp;
      udpPortsStr = lib.concatMapStringsSep ", " toString fwCfg.openPorts.udp;

      # Build port forward rules from machines
      machinesByName = lib.listToAttrs (map (m: lib.nameValuePair m.name m) cfg.machines);

      forwardRules = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          _: machine:
          lib.concatStringsSep "\n" (
            map (
              pf:
              "iifname \"${wan}\" oifname \"${lanIface}\" ip daddr ${subnet}.${toString machine.ip} ${pf.protocol} dport ${toString pf.port} accept"
            ) machine.portForwards
          )
        ) machinesByName
      );

      dnatRules = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          _: machine:
          lib.concatStringsSep "\n" (
            map (
              pf:
              "iifname \"${wan}\" ${pf.protocol} dport ${toString pf.port} dnat to ${subnet}.${toString machine.ip}"
            ) machine.portForwards
          )
        ) machinesByName
      );

      # Hairpin NAT: DNAT rules for LAN clients accessing port-forwarded services via the public IP
      hairpinDnatRules = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          _: machine:
          lib.concatStringsSep "\n" (
            map (
              pf:
              "iifname \"${lanIface}\" ${pf.protocol} dport ${toString pf.port} dnat to ${subnet}.${toString machine.ip} comment \"Hairpin DNAT\""
            ) machine.portForwards
          )
        ) machinesByName
      );
    in
    {
      options.my.router.firewall = {
        trustedInterfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "zt0"
            "wg0"
          ];
          description = "Additional trusted interfaces (VPN, etc.)";
        };
        openPorts = {
          tcp = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            example = [
              80
              443
            ];
            description = "TCP ports to open on WAN (empty by default for security)";
          };
          udp = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            example = [ 51820 ];
            description = "UDP ports to open on WAN";
          };
        };
        extraInputRules = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Additional nftables rules injected into the IPv4 input chain";
        };
        extraInputRulesV6 = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Additional nftables rules injected into the IPv6 input chain";
        };
        wanDropLogRate = lib.mkOption {
          type = lib.types.str;
          default = "30/minute";
          description = "Rate limit for kernel logging of dropped WAN input packets (nftables format)";
        };
        wanDropLogBurst = lib.mkOption {
          type = lib.types.int;
          default = 20;
          description = "Burst limit for kernel logging of dropped WAN input packets";
        };
        hairpinNat = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable hairpin NAT (NAT reflection) so LAN clients can access WAN-facing services via the router's public IP";
          };
        };
        rateLimiting = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable rate limiting on WAN to prevent DoS";
          };
          icmpRate = lib.mkOption {
            type = lib.types.str;
            default = "10/second";
            description = "Per-source-IP WAN ICMPv4 echo-request rate limit (nftables format)";
          };
          icmpBurst = lib.mkOption {
            type = lib.types.int;
            default = 20;
            description = "Per-source-IP WAN ICMPv4 echo-request burst limit";
          };
          icmpv6Rate = lib.mkOption {
            type = lib.types.str;
            default = "20/second";
            description = "Per-/64-prefix WAN ICMPv6 echo-request rate limit (nftables format)";
          };
          icmpv6Burst = lib.mkOption {
            type = lib.types.int;
            default = 40;
            description = "Per-/64-prefix WAN ICMPv6 echo-request burst limit";
          };
          newConnRate = lib.mkOption {
            type = lib.types.str;
            default = "25/second";
            description = "Per-source-IP WAN new connection rate limit";
          };
          newConnBurst = lib.mkOption {
            type = lib.types.int;
            default = 50;
            description = "Per-source-IP WAN new connection burst limit";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        networking.nftables = {
          enable = true;
          tables = {
            filterV4 = {
              family = "ip";
              content = ''
                ${lib.optionalString (allTrustedInterfaces != [ ]) (
                  mkIfaceSet "trusted_ifaces" allTrustedInterfaces
                )}
                ${lib.optionalString (unifiControllerInterfaces != [ ]) (
                  mkIfaceSet "unifi_ifaces" unifiControllerInterfaces
                )}
                ${lib.optionalString fwCfg.rateLimiting.enable ''
                  set wan_icmpv4 {
                    type ipv4_addr
                    size 65535
                    flags dynamic, timeout
                    timeout 1m
                  }
                ''}
                ${lib.optionalString (fwCfg.rateLimiting.enable && fwCfg.openPorts.tcp != [ ]) ''
                  set wan_new_tcp {
                    type ipv4_addr
                    size 65535
                    flags dynamic, timeout
                    timeout 1m
                  }
                ''}
                ${lib.optionalString (fwCfg.rateLimiting.enable && fwCfg.openPorts.udp != [ ]) ''
                  set wan_new_udp {
                    type ipv4_addr
                    size 65535
                    flags dynamic, timeout
                    timeout 1m
                  }
                ''}

                # Named counters — exported to Prometheus via the
                # nftables-metrics textfile collector (observability module)
                counter wan_input_drop { }
                counter wan_new_accept_tcp { }
                counter wan_new_accept_udp { }

                ${lib.optionalString (fwCfg.openPorts.tcp != [ ]) ''
                  chain accept_wan_tcp {
                    counter name wan_new_accept_tcp comment "Count accepted new WAN TCP"
                    limit rate 1/second burst 20 packets log prefix "nft-wan-accept: " comment "Log new WAN TCP (source IPs)"
                    accept
                  }
                ''}
                ${lib.optionalString (fwCfg.openPorts.udp != [ ]) ''
                  chain accept_wan_udp {
                    counter name wan_new_accept_udp comment "Count accepted new WAN UDP"
                    limit rate 1/second burst 20 packets log prefix "nft-wan-accept: " comment "Log new WAN UDP (source IPs)"
                    accept
                  }
                ''}

                chain input {
                  type filter hook input priority 0; policy drop;

                  # Early accepts
                  iifname "lo" accept
                  ct state established,related accept
                  ct state invalid drop

                  # Anti-spoofing: Drop packets with bogon/martian source IPs on WAN (BCP38)
                  iifname "${wan}" ip saddr {
                    0.0.0.0/8,        # "This" network
                    10.0.0.0/8,       # RFC1918 private
                    127.0.0.0/8,      # Loopback
                    169.254.0.0/16,   # Link-local
                    172.16.0.0/12,    # RFC1918 private
                    192.0.0.0/24,     # IETF protocol assignments
                    192.0.2.0/24,     # TEST-NET-1
                    192.168.0.0/16,   # RFC1918 private
                    198.18.0.0/15,    # Benchmark testing
                    198.51.100.0/24,  # TEST-NET-2
                    203.0.113.0/24,   # TEST-NET-3
                    224.0.0.0/4,      # Multicast
                    240.0.0.0/4       # Reserved
                  } drop comment "Anti-spoofing bogons"

                  # Port scan detection: Drop malformed TCP flag combinations
                  iifname "${wan}" tcp flags & (fin|syn|rst|psh|ack|urg) == (fin|psh|urg) drop comment "XMAS scan"
                  iifname "${wan}" tcp flags & (fin|syn) == (fin|syn) drop comment "FIN+SYN scan"
                  iifname "${wan}" tcp flags & (syn|rst) == (syn|rst) drop comment "SYN+RST scan"
                  iifname "${wan}" tcp flags == 0x0 drop comment "NULL scan"

                  # LAN input rules are handled by vlans.nix (all segments are tagged VLANs)

                  # Trusted interfaces (VPN tunnels, etc.)
                  ${lib.optionalString (allTrustedInterfaces != [ ]) "iifname @trusted_ifaces accept"}

                  # Debug uplink: SSH access only (not full trust)
                  ${lib.optionalString cfg.debugUplink.enable ''
                    iifname "${cfg.debugUplink.interface}" tcp dport 22 accept comment "Debug uplink: SSH only"
                  ''}

                  # mDNS input rules (injected from mdns.nix)
                  ${mdnsFw.inputRules}

                  # SSDP relay input rules (injected from ssdp-relay.nix)
                  ${ssdpFw.inputRules}

                  # Network/VLAN input rules (injected)
                  ${netFw.inputRules}

                  # Monitoring input rules (injected)
                  ${monFw.inputRules}

                  # Unifi controller input rules (injected)
                  ${unifiFw.inputRules}

                  # Machine-specific input rules
                  ${fwCfg.extraInputRules}

                  # WAN input rules (solicited echo-reply already accepted by ct state established,related)
                  ${
                    if fwCfg.rateLimiting.enable then
                      ''iifname "${wan}" icmp type echo-request update @wan_icmpv4 { ip saddr limit rate ${fwCfg.rateLimiting.icmpRate} burst ${toString fwCfg.rateLimiting.icmpBurst} packets } accept comment "ICMP ping per-IP rate limited"''
                    else
                      ''iifname "${wan}" icmp type echo-request accept comment "ICMP ping"''
                  }
                  ${lib.optionalString (fwCfg.openPorts.tcp != [ ]) (
                    if fwCfg.rateLimiting.enable then
                      ''iifname "${wan}" ct state new tcp dport { ${tcpPortsStr} } update @wan_new_tcp { ip saddr limit rate ${fwCfg.rateLimiting.newConnRate} burst ${toString fwCfg.rateLimiting.newConnBurst} packets } jump accept_wan_tcp comment "Open TCP ports (per-IP rate limited)"''
                    else
                      ''iifname "${wan}" ct state new tcp dport { ${tcpPortsStr} } jump accept_wan_tcp comment "Open TCP ports"''
                  )}
                  ${lib.optionalString (fwCfg.openPorts.udp != [ ]) (
                    if fwCfg.rateLimiting.enable then
                      ''iifname "${wan}" ct state new udp dport { ${udpPortsStr} } update @wan_new_udp { ip saddr limit rate ${fwCfg.rateLimiting.newConnRate} burst ${toString fwCfg.rateLimiting.newConnBurst} packets } jump accept_wan_udp comment "Open UDP ports (per-IP rate limited)"''
                    else
                      ''iifname "${wan}" ct state new udp dport { ${udpPortsStr} } jump accept_wan_udp comment "Open UDP ports"''
                  )}

                  # Hairpin NAT: accept WAN-facing ports from LAN (for router-local services such as Headscale)
                  ${lib.optionalString (fwCfg.hairpinNat.enable && fwCfg.openPorts.tcp != [ ]) ''
                    iifname "${lanIface}" tcp dport { ${tcpPortsStr} } accept comment "Hairpin: open TCP ports from LAN"
                  ''}
                  ${lib.optionalString (fwCfg.hairpinNat.enable && fwCfg.openPorts.udp != [ ]) ''
                    iifname "${lanIface}" udp dport { ${udpPortsStr} } accept comment "Hairpin: open UDP ports from LAN"
                  ''}

                  # WAN drop accounting: count everything, log with a higher
                  # budget than LAN so scan sources are visible in Loki
                  iifname "${wan}" counter name wan_input_drop comment "Count WAN input drops"
                  iifname "${wan}" limit rate ${fwCfg.wanDropLogRate} burst ${toString fwCfg.wanDropLogBurst} packets log prefix "nft-drop-wan: " level info
                  # Log dropped packets for forensics (rate limited to prevent log flooding)
                  iifname != "${wan}" limit rate 5/minute burst 10 packets log prefix "nft-drop-input: " level info
                }

                chain forward {
                  type filter hook forward priority 0; policy drop;

                  # MSS clamping - must be before accept rules (fixes PPPoE/tunnel MTU issues)
                  tcp flags syn / syn,rst tcp option maxseg size set rt mtu

                  # Early accepts for established connections (critical for return traffic)
                  ct state established,related accept
                  ct state invalid drop

                  # LAN forwarding is handled by vlans.nix (all segments are tagged VLANs)

                  # Trusted interfaces (VPN tunnels) ↔ main LAN
                  ${lib.optionalString (allTrustedInterfaces != [ ]) ''
                    iifname @trusted_ifaces oifname "${lanIface}" accept
                    iifname "${lanIface}" oifname @trusted_ifaces accept
                    iifname @trusted_ifaces oifname @trusted_ifaces accept comment "VPN peer-to-peer"
                    iifname @trusted_ifaces oifname "${wan}" accept''}

                  # Port forwarding rules
                  ${forwardRules}

                  # SSDP relay forwarding rules (injected from ssdp-relay.nix)
                  ${ssdpFw.forwardRules}

                  # Network/VLAN forwarding rules (injected)
                  ${netFw.forwardRules}

                  # Log dropped packets for forensics (rate limited)
                  limit rate 5/minute burst 10 packets log prefix "nft-drop-forward: " level info
                }
              '';
            };
            natV4 = {
              family = "ip";
              content = ''
                chain prerouting {
                  type nat hook prerouting priority -100;
                  ${dnatRules}
                  # Hairpin NAT: DNAT for LAN clients accessing port-forwarded services via public IP
                  ${lib.optionalString fwCfg.hairpinNat.enable hairpinDnatRules}
                }
                chain postrouting {
                  type nat hook postrouting priority 100;
                  # Scoped to RFC1918: prevents NAT of unexpected traffic from routing misconfigs
                  ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } oifname "${wan}" masquerade
                  # Hairpin NAT: masquerade LAN-to-LAN DNAT'd traffic so return path goes through router
                  ${lib.optionalString fwCfg.hairpinNat.enable ''
                    iifname "${lanIface}" oifname "${lanIface}" ct status dnat masquerade comment "Hairpin NAT"
                  ''}
                  ${netFw.natRules}
                }
              '';
            };
            # Note: MSS clamping is now in filterV4/filterV6 forward chains
            # Removed separate forwardV4/forwardV6 tables that caused duplicate chain issues
            filterV6 = lib.mkIf cfg.ipv6.enable {
              family = "ip6";
              content = ''
                ${lib.optionalString (allTrustedInterfaces != [ ]) (
                  mkIfaceSet "trusted_ifaces" allTrustedInterfaces
                )}
                ${lib.optionalString fwCfg.rateLimiting.enable ''
                  set wan_icmpv6 {
                    type ipv6_addr
                    size 65535
                    flags dynamic, timeout
                    timeout 1m
                  }
                ''}
                ${lib.optionalString (fwCfg.rateLimiting.enable && fwCfg.openPorts.tcp != [ ]) ''
                  set wan_new_tcp {
                    type ipv6_addr
                    size 65535
                    flags dynamic, timeout
                    timeout 1m
                  }
                ''}
                ${lib.optionalString (fwCfg.rateLimiting.enable && fwCfg.openPorts.udp != [ ]) ''
                  set wan_new_udp {
                    type ipv6_addr
                    size 65535
                    flags dynamic, timeout
                    timeout 1m
                  }
                ''}

                # Named counters, exported via nftables-metrics textfile collector
                counter wan_input_drop { }
                counter wan_new_accept_tcp { }
                counter wan_new_accept_udp { }

                ${lib.optionalString (fwCfg.openPorts.tcp != [ ]) ''
                  chain accept_wan_tcp {
                    counter name wan_new_accept_tcp comment "Count accepted new WAN IPv6 TCP"
                    limit rate 1/second burst 20 packets log prefix "nft6-wan-accept: " comment "Log new WAN IPv6 TCP (source IPs)"
                    accept
                  }
                ''}
                ${lib.optionalString (fwCfg.openPorts.udp != [ ]) ''
                  chain accept_wan_udp {
                    counter name wan_new_accept_udp comment "Count accepted new WAN IPv6 UDP"
                    limit rate 1/second burst 20 packets log prefix "nft6-wan-accept: " comment "Log new WAN IPv6 UDP (source IPs)"
                    accept
                  }
                ''}

                chain input {
                  type filter hook input priority 0; policy drop;

                  # Early accepts
                  iifname "lo" accept
                  ct state established,related accept
                  ct state invalid drop

                  # IPv6 anti-spoofing on WAN (expanded bogon list per IANA special-purpose registry)
                  # Note: fe80::/10 (link-local) NOT blocked — needed for RA, NDP, DHCPv6 from ISP.
                  # Unsolicited RAs arrive with fe80:: source BEFORE ct state can track them.
                  iifname "${wan}" ip6 saddr {
                    ::1/128,          # Loopback
                    ::/128,           # Unspecified
                    ::ffff:0:0/96,    # IPv4-mapped
                    fc00::/7,         # Unique local (ULA) - shouldn't arrive from WAN
                    2001:db8::/32,    # Documentation range
                    100::/64,         # Discard-only (RFC 6666)
                    ff00::/8          # Multicast as source
                  } drop comment "IPv6 anti-spoofing bogons"

                  # LAN IPv6 input rules are handled by vlans.nix

                  # mDNS input rules (injected from mdns.nix)
                  ${mdnsFw.inputRulesV6}

                  # Trusted interfaces
                  ${lib.optionalString (allTrustedInterfaces != [ ]) "iifname @trusted_ifaces accept"}

                  # Machine-specific input rules
                  ${fwCfg.extraInputRulesV6}

                  # WAN input rules - ICMPv6 required for IPv6 operation
                  # Per-/64-prefix rate limit echo-request to prevent ping floods
                  ${
                    if fwCfg.rateLimiting.enable then
                      ''iifname "${wan}" icmpv6 type echo-request update @wan_icmpv6 { ip6 saddr & ffff:ffff:ffff:ffff:: limit rate ${fwCfg.rateLimiting.icmpv6Rate} burst ${toString fwCfg.rateLimiting.icmpv6Burst} packets } accept comment "ICMPv6 ping per-prefix rate limited"''
                    else
                      ''iifname "${wan}" icmpv6 type echo-request accept comment "ICMPv6 ping"''
                  }
                  iifname "${wan}" icmpv6 type {
                    destination-unreachable, packet-too-big, time-exceeded,
                    parameter-problem, nd-neighbor-solicit, nd-neighbor-advert
                  } accept comment "ICMPv6 required for IPv6"
                  # Router advertisements from ISP (needed for SLAAC/DHCP-PD)
                  iifname "${wan}" icmpv6 type nd-router-advert accept comment "ISP router advertisements"
                  iifname "${wan}" ip6 daddr fe80::/64 udp sport 547 udp dport 546 accept comment "DHCPv6 from ISP"
                  ${lib.optionalString (fwCfg.openPorts.tcp != [ ]) (
                    if fwCfg.rateLimiting.enable then
                      ''iifname "${wan}" ct state new tcp dport { ${tcpPortsStr} } update @wan_new_tcp { ip6 saddr & ffff:ffff:ffff:ffff:: limit rate ${fwCfg.rateLimiting.newConnRate} burst ${toString fwCfg.rateLimiting.newConnBurst} packets } jump accept_wan_tcp comment "Open TCP ports (per-prefix rate limited)"''
                    else
                      ''iifname "${wan}" ct state new tcp dport { ${tcpPortsStr} } jump accept_wan_tcp comment "Open TCP ports"''
                  )}
                  ${lib.optionalString (fwCfg.openPorts.udp != [ ]) (
                    if fwCfg.rateLimiting.enable then
                      ''iifname "${wan}" ct state new udp dport { ${udpPortsStr} } update @wan_new_udp { ip6 saddr & ffff:ffff:ffff:ffff:: limit rate ${fwCfg.rateLimiting.newConnRate} burst ${toString fwCfg.rateLimiting.newConnBurst} packets } jump accept_wan_udp comment "Open UDP ports (per-prefix rate limited)"''
                    else
                      ''iifname "${wan}" ct state new udp dport { ${udpPortsStr} } jump accept_wan_udp comment "Open UDP ports"''
                  )}

                  # Hairpin: accept WAN-facing ports from LAN
                  ${lib.optionalString (fwCfg.hairpinNat.enable && fwCfg.openPorts.tcp != [ ]) ''
                    iifname "${lanIface}" tcp dport { ${tcpPortsStr} } accept comment "Hairpin: open TCP ports from LAN"
                  ''}
                  ${lib.optionalString (fwCfg.hairpinNat.enable && fwCfg.openPorts.udp != [ ]) ''
                    iifname "${lanIface}" udp dport { ${udpPortsStr} } accept comment "Hairpin: open UDP ports from LAN"
                  ''}

                  # RA Guard: Block rogue router advertisements from LAN clients (input chain)
                  # Note: This only protects the router — see raGuard bridge table for LAN client protection
                  iifname "${lanIface}" icmpv6 type nd-router-advert drop comment "RA Guard - block rogue RAs from LAN"

                  # WAN drop accounting (see filterV4 for rationale)
                  iifname "${wan}" counter name wan_input_drop comment "Count WAN input drops"
                  iifname "${wan}" limit rate ${fwCfg.wanDropLogRate} burst ${toString fwCfg.wanDropLogBurst} packets log prefix "nft6-drop-wan: " level info
                  # Log dropped packets for forensics (rate limited)
                  iifname != "${wan}" limit rate 5/minute burst 10 packets log prefix "nft6-drop-input: " level info
                }

                chain forward {
                  type filter hook forward priority 0; policy drop;

                  # MSS clamping - must be before accept rules (fixes PPPoE/tunnel MTU issues)
                  tcp flags syn / syn,rst tcp option maxseg size set rt mtu

                  # Early accepts for established connections
                  ct state established,related accept
                  ct state invalid drop

                  # LAN IPv6 forwarding is handled by vlans.nix

                  # Trusted interfaces (VPN tunnels) ↔ main LAN
                  ${lib.optionalString (allTrustedInterfaces != [ ]) ''
                    iifname @trusted_ifaces oifname "${lanIface}" accept
                    iifname "${lanIface}" oifname @trusted_ifaces accept
                    iifname @trusted_ifaces oifname @trusted_ifaces accept comment "VPN peer-to-peer"
                    iifname @trusted_ifaces oifname "${wan}" accept''}

                  # Log dropped packets for forensics (rate limited)
                  limit rate 5/minute burst 10 packets log prefix "nft6-drop-forward: " level info
                }
              '';
            };

            # Flow offload via NixOS nftables module - declarative and cleaner
            # Uses bridge interfaces - kernel 5.13+ discovers bridge ports automatically
            flow_offload =
              let
                # Get all bridge names from network segments
                bridges =
                  if networksCfg.enable then
                    [ "br-lan" ]
                    ++ lib.mapAttrsToList (name: _: "br-${name}") (
                      lib.filterAttrs (_name: seg: seg.vlan != null) networksCfg.segments
                    )
                  else
                    [ "br-lan" ];
                # Veth pairs connecting br-lan to per-VLAN bridges
                veths =
                  if networksCfg.enable then
                    lib.concatMap (name: [
                      "v-${name}"
                      "v-${name}-br"
                    ]) (lib.attrNames (lib.filterAttrs (_: seg: seg.vlan != null) networksCfg.segments))
                  else
                    [ ];
                # WAN + all bridges + veth pairs (all devices in the forwarding path)
                flowDevices = [ wan ] ++ bridges ++ veths;
                deviceList = lib.concatStringsSep ", " flowDevices;
              in
              {
                family = "inet";
                content = ''
                  # Flowtable for software flow offload - bypasses netfilter for established flows
                  # Kernel 5.13+ discovers bridge ports automatically
                  flowtable f {
                    hook ingress priority 0
                    devices = { ${deviceList} }
                    counter
                  }

                  chain forward {
                    type filter hook forward priority -100; policy accept;
                    # Only offload established/related - first packets go through full firewall
                    ct state established,related ip protocol { tcp, udp } flow offload @f counter
                    ct state established,related ip6 nexthdr { tcp, udp } flow offload @f counter
                  }
                '';
              };

            # Bridge-level RA Guard: blocks rogue Router Advertisements at L2
            # The input chain RA Guard only protects the router itself. Rogue RAs are
            # multicast at L2 on the bridge, reaching all LAN hosts directly.
            # This bridge-family table drops RAs forwarded between bridge ports.
            # Router's own RAs originate from the local stack (bridge output), not forward.
            raGuard = {
              family = "bridge";
              content = ''
                chain forward {
                  type filter hook forward priority -200; policy accept;
                  ether type ip6 icmpv6 type nd-router-advert drop comment "RA Guard: block rogue RAs on bridge"
                }
              '';
            };
          };

          # Flowtable device validation workaround for build sandbox
          # Replace device lists with loopback (always exists) during nft check
          # See: https://github.com/NixOS/nixpkgs/issues/141802
          preCheckRuleset = ''
            sed 's/.*devices.*/devices = { lo }/g' -i ruleset.conf
          '';
        };

        # Fix nftables service ordering - must start AFTER interfaces exist
        # Default NixOS module sets before=["network-pre.target"], but we need
        # nftables AFTER network-pre.target so flowtable devices exist
        systemd.services.nftables = {
          before = lib.mkForce [ ];
          after = [ "network-pre.target" ];
          # Force restart instead of reload on config changes.
          # NixOS defaults to X-ReloadIfChanged=true, but nftables reload cannot
          # update flowtable device bindings — the kernel rejects in-place changes
          # to live flowtable devices, causing the entire reload to fail silently
          # (old ruleset stays active, new rules never apply).
          reloadIfChanged = lib.mkForce false;
        };

        # Ensure flow offload kernel modules are loaded
        boot.kernelModules = [
          "nf_flow_table"
          "nf_flow_table_inet"
        ];

        # Conntrack and bridge netfilter tuning for router performance
        boot.kernel.sysctl = {
          # nf_conntrack_max is set in network.nix - don't duplicate
          "net.netfilter.nf_conntrack_tcp_timeout_established" = lib.mkDefault 7200;
          # Disable bridge-nf-call: forces all bridged L2 frames through netfilter,
          # causing performance overhead and unexpected interactions with nftables rules.
          # Only enable if running containers (Docker/podman) that need it.
          "net.bridge.bridge-nf-call-iptables" = lib.mkDefault 0;
          "net.bridge.bridge-nf-call-ip6tables" = lib.mkDefault 0;
        };
      };
    };
}
