_: {
  flake.modules.nixos.routerFirewall =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.router;
      fwCfg = cfg.firewall;
      networksCfg = cfg.networks;
      internal = cfg._internal;
      inherit (internal) lanSubnet;
      wan = cfg.wan.interface;
      inherit (internal) lanDevice;

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

      # H3: Debug uplink is NOT added to trusted interfaces — gets SSH-only access instead
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
              "iifname \"${wan}\" oifname \"${lanDevice}\" ip daddr ${lanSubnet}.${toString machine.ip} ${pf.protocol} dport ${toString pf.port} accept"
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
              "iifname \"${wan}\" ${pf.protocol} dport ${toString pf.port} dnat to ${lanSubnet}.${toString machine.ip}"
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
              "iifname \"${lanDevice}\" ${pf.protocol} dport ${toString pf.port} dnat to ${lanSubnet}.${toString machine.ip} comment \"Hairpin DNAT\""
            ) machine.portForwards
          )
        ) machinesByName
      );
    in
    {
      options.features.router.firewall = {
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
            description = "ICMP rate limit (nftables format)";
          };
          icmpBurst = lib.mkOption {
            type = lib.types.int;
            default = 50;
            description = "ICMP burst limit";
          };
          newConnRate = lib.mkOption {
            type = lib.types.str;
            default = "100/second";
            description = "New connection rate limit";
          };
          newConnBurst = lib.mkOption {
            type = lib.types.int;
            default = 200;
            description = "New connection burst limit";
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

                  # LAN input rules
                  iifname "${lanDevice}" udp dport 67 limit rate 10/second burst 50 packets accept comment "DHCP (rate limited)"
                  iifname "${lanDevice}" tcp dport 53 accept comment "DNS TCP"
                  iifname "${lanDevice}" ct state new tcp dport 22 limit rate 5/minute burst 10 packets accept comment "SSH (rate limited)"
                  iifname "${lanDevice}" udp dport { 53, 123 } accept comment "DNS, NTP UDP"
                  iifname "${lanDevice}" icmp type { echo-request, echo-reply } accept

                  # Trusted interfaces (VPN tunnels, etc.)
                  ${lib.optionalString (allTrustedInterfaces != [ ]) "iifname @trusted_ifaces accept"}

                  # H3: Debug uplink — SSH access only (not full trust)
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

                  # WAN input rules
                  ${
                    if fwCfg.rateLimiting.enable then
                      ''
                        iifname "${wan}" icmp type echo-request limit rate ${fwCfg.rateLimiting.icmpRate} burst ${toString fwCfg.rateLimiting.icmpBurst} packets accept comment "ICMP ping rate limited"
                        iifname "${wan}" icmp type echo-reply accept comment "Allow ping responses"''
                    else
                      ''iifname "${wan}" icmp type { echo-request, echo-reply } accept''
                  }
                  ${lib.optionalString (fwCfg.openPorts.tcp != [ ]) (
                    if fwCfg.rateLimiting.enable then
                      ''iifname "${wan}" ct state new tcp dport { ${tcpPortsStr} } limit rate ${fwCfg.rateLimiting.newConnRate} burst ${toString fwCfg.rateLimiting.newConnBurst} packets accept comment "Open TCP ports (rate limited)"''
                    else
                      ''iifname "${wan}" tcp dport { ${tcpPortsStr} } accept comment "Open TCP ports"''
                  )}
                  ${lib.optionalString (fwCfg.openPorts.udp != [ ]) (
                    if fwCfg.rateLimiting.enable then
                      ''iifname "${wan}" ct state new udp dport { ${udpPortsStr} } limit rate ${fwCfg.rateLimiting.newConnRate} burst ${toString fwCfg.rateLimiting.newConnBurst} packets accept comment "Open UDP ports (rate limited)"''
                    else
                      ''iifname "${wan}" udp dport { ${udpPortsStr} } accept comment "Open UDP ports"''
                  )}

                  # Hairpin NAT: accept WAN-facing ports from LAN (for router-local services like WireGuard)
                  ${lib.optionalString (fwCfg.hairpinNat.enable && fwCfg.openPorts.tcp != [ ]) ''
                    iifname "${lanDevice}" tcp dport { ${tcpPortsStr} } accept comment "Hairpin: open TCP ports from LAN"
                  ''}
                  ${lib.optionalString (fwCfg.hairpinNat.enable && fwCfg.openPorts.udp != [ ]) ''
                    iifname "${lanDevice}" udp dport { ${udpPortsStr} } accept comment "Hairpin: open UDP ports from LAN"
                  ''}

                  # L1: Log dropped packets for forensics (rate limited to prevent log flooding)
                  limit rate 5/minute burst 10 packets log prefix "nft-drop-input: " level info
                }

                chain forward {
                  type filter hook forward priority 0; policy drop;

                  # MSS clamping - must be before accept rules (fixes PPPoE/tunnel MTU issues)
                  tcp flags syn / syn,rst tcp option maxseg size set rt mtu

                  # Early accepts for established connections (critical for return traffic)
                  ct state established,related accept
                  ct state invalid drop

                  # LAN forwarding
                  iifname "${lanDevice}" oifname "${wan}" accept
                  iifname "${lanDevice}" oifname "${lanDevice}" accept

                  # Trusted interfaces
                  ${lib.optionalString (allTrustedInterfaces != [ ]) ''
                    iifname @trusted_ifaces oifname "${lanDevice}" accept
                    iifname "${lanDevice}" oifname @trusted_ifaces accept
                    iifname @trusted_ifaces oifname @trusted_ifaces accept comment "VPN peer-to-peer"
                    iifname @trusted_ifaces oifname "${wan}" accept''}

                  # Port forwarding rules
                  ${forwardRules}

                  # SSDP relay forwarding rules (injected from ssdp-relay.nix)
                  ${ssdpFw.forwardRules}

                  # Network/VLAN forwarding rules (injected)
                  ${netFw.forwardRules}

                  # L1: Log dropped packets for forensics (rate limited)
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
                  # M1: Scoped to RFC1918 — prevents NAT of unexpected traffic from routing misconfigs
                  ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } oifname "${wan}" masquerade
                  # Hairpin NAT: masquerade LAN-to-LAN DNAT'd traffic so return path goes through router
                  ${lib.optionalString fwCfg.hairpinNat.enable ''
                    iifname "${lanDevice}" oifname "${lanDevice}" ct status dnat masquerade comment "Hairpin NAT"
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

                chain input {
                  type filter hook input priority 0; policy drop;

                  # Early accepts
                  iifname "lo" accept
                  ct state established,related accept
                  ct state invalid drop

                  # M2: IPv6 anti-spoofing on WAN (expanded bogon list per IANA special-purpose registry)
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

                  # LAN input rules
                  iifname "${lanDevice}" tcp dport 53 accept comment "DNS TCP"
                  iifname "${lanDevice}" ct state new tcp dport 22 limit rate 5/minute burst 10 packets accept comment "SSH (rate limited)"
                  iifname "${lanDevice}" udp dport 53 accept comment "DNS UDP"
                  iifname "${lanDevice}" icmpv6 type { echo-request, echo-reply, nd-neighbor-solicit, nd-neighbor-advert } accept comment "ICMPv6"

                  # mDNS input rules (injected from mdns.nix)
                  ${mdnsFw.inputRulesV6}

                  # Trusted interfaces
                  ${lib.optionalString (allTrustedInterfaces != [ ]) "iifname @trusted_ifaces accept"}

                  # WAN input rules - ICMPv6 required for IPv6 operation
                  # Rate limit echo-request to prevent ping floods
                  iifname "${wan}" icmpv6 type echo-request limit rate 10/second burst 50 packets accept comment "ICMPv6 ping rate limited"
                  iifname "${wan}" icmpv6 type {
                    destination-unreachable, packet-too-big, time-exceeded,
                    parameter-problem, nd-neighbor-solicit, nd-neighbor-advert
                  } accept comment "ICMPv6 required for IPv6"
                  # Router advertisements from ISP (needed for SLAAC/DHCP-PD)
                  iifname "${wan}" icmpv6 type nd-router-advert accept comment "ISP router advertisements"
                  iifname "${wan}" udp dport dhcpv6-client udp sport dhcpv6-server accept comment "DHCPv6 from ISP"

                  # RA Guard: Block rogue router advertisements from LAN clients (input chain)
                  # Note: This only protects the router — see raGuard bridge table for LAN client protection
                  iifname "${lanDevice}" icmpv6 type nd-router-advert drop comment "RA Guard - block rogue RAs from LAN"

                  # L1: Log dropped packets for forensics (rate limited)
                  limit rate 5/minute burst 10 packets log prefix "nft6-drop-input: " level info
                }

                chain forward {
                  type filter hook forward priority 0; policy drop;

                  # MSS clamping - must be before accept rules (fixes PPPoE/tunnel MTU issues)
                  tcp flags syn / syn,rst tcp option maxseg size set rt mtu

                  # Early accepts for established connections
                  ct state established,related accept
                  ct state invalid drop

                  # LAN forwarding
                  iifname "${lanDevice}" oifname "${wan}" accept

                  # Trusted interfaces
                  ${lib.optionalString (allTrustedInterfaces != [ ]) ''
                    iifname @trusted_ifaces oifname "${lanDevice}" accept
                    iifname "${lanDevice}" oifname @trusted_ifaces accept
                    iifname @trusted_ifaces oifname @trusted_ifaces accept comment "VPN peer-to-peer"
                    iifname @trusted_ifaces oifname "${wan}" accept''}

                  # L1: Log dropped packets for forensics (rate limited)
                  limit rate 5/minute burst 10 packets log prefix "nft6-drop-forward: " level info
                }
              '';
            };
          };
        };

        # Flowtable device validation workaround for build sandbox
        # Replace device lists with loopback (always exists) during nft check
        # See: https://github.com/NixOS/nixpkgs/issues/141802
        networking.nftables.preCheckRuleset = ''
          sed 's/.*devices.*/devices = { lo }/g' -i ruleset.conf
        '';

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

        # Flow offload via NixOS nftables module - declarative and cleaner
        # Uses bridge interfaces - kernel 5.13+ discovers bridge ports automatically
        networking.nftables.tables.flow_offload =
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
            # WAN + all bridges (kernel discovers bridge ports for flow offload)
            flowDevices = [ wan ] ++ bridges;
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

        # H1: Bridge-level RA Guard — blocks rogue Router Advertisements at L2
        # The input chain RA Guard only protects the router itself. Rogue RAs are
        # multicast at L2 on the bridge, reaching all LAN hosts directly.
        # This bridge-family table drops RAs forwarded between bridge ports.
        # Router's own RAs originate from the local stack (bridge output), not forward.
        networking.nftables.tables.raGuard = {
          family = "bridge";
          content = ''
            chain forward {
              type filter hook forward priority -200; policy accept;
              ether type ip6 icmpv6 type nd-router-advert drop comment "RA Guard: block rogue RAs on bridge"
            }
          '';
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
          # M3: Disable bridge-nf-call — forces all bridged L2 frames through netfilter,
          # causing performance overhead and unexpected interactions with nftables rules.
          # Only enable if running containers (Docker/podman) that need it.
          "net.bridge.bridge-nf-call-iptables" = lib.mkDefault 0;
          "net.bridge.bridge-nf-call-ip6tables" = lib.mkDefault 0;
        };
      };
    };
}
