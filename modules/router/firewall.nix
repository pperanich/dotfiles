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
      hostapdCfg = cfg.hostapd;
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

      # Get monitoring firewall rules if monitoring is enabled
      monFw =
        internal.monitoringFirewall or {
          inputRules = "";
        };

      # Wireless interfaces (if hostapd enabled) - only non-bridged ones need explicit rules
      wlanInterfaces = if hostapdCfg.enable then hostapdCfg._internal.nonBridgedInterfaces else [ ];

      # Generate firewall rules for wireless interfaces
      mkWlanInputRules = iface: ''
        iifname "${iface}" udp dport 67 accept comment "DHCP (${iface})"
        iifname "${iface}" tcp dport { 53, 22 } accept comment "DNS TCP, SSH (${iface})"
        iifname "${iface}" udp dport 53 accept comment "DNS UDP (${iface})"
        iifname "${iface}" icmp type { echo-request, echo-reply } accept'';

      mkWlanInputRulesV6 = iface: ''
        iifname "${iface}" tcp dport { 53, 22 } accept comment "DNS TCP, SSH (${iface})"
        iifname "${iface}" udp dport 53 accept comment "DNS UDP (${iface})"
        iifname "${iface}" icmpv6 type { echo-request, echo-reply, nd-neighbor-solicit, nd-neighbor-advert } accept comment "ICMPv6 (${iface})"'';

      mkWlanForwardRules = iface: ''
        iifname "${iface}" oifname "${wan}" accept
        iifname "${iface}" oifname "${lanDevice}" accept
        iifname "${lanDevice}" oifname "${iface}" accept
        iifname "${wan}" oifname "${iface}" ct state established,related accept'';

      wlanInputRules = lib.concatMapStringsSep "\n" mkWlanInputRules wlanInterfaces;
      wlanInputRulesV6 = lib.concatMapStringsSep "\n" mkWlanInputRulesV6 wlanInterfaces;
      wlanForwardRules = lib.concatMapStringsSep "\n" mkWlanForwardRules wlanInterfaces;

      # Build trusted interface rules (auto-include debug uplink if enabled)
      allTrustedInterfaces =
        fwCfg.trustedInterfaces ++ lib.optional cfg.debugUplink.enable cfg.debugUplink.interface;

      trustedInputRules = lib.concatMapStringsSep "\n" (
        iface: ''iifname "${iface}" accept''
      ) allTrustedInterfaces;

      trustedForwardRules = lib.concatMapStringsSep "\n" (iface: ''
        iifname "${iface}" oifname "${lanDevice}" accept
        iifname "${lanDevice}" oifname "${iface}" accept
        iifname "${iface}" oifname "${wan}" accept'') allTrustedInterfaces;

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
            default = [
              80
              443
            ];
            description = "TCP ports to open on WAN";
          };
          udp = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            example = [ 51820 ];
            description = "UDP ports to open on WAN";
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
                chain input {
                  type filter hook input priority 0; policy drop;

                  # Early accepts
                  iifname "lo" accept
                  ct state established,related accept
                  ct state invalid drop

                  # LAN input rules
                  iifname "${lanDevice}" udp dport 67 accept comment "DHCP"
                  iifname "${lanDevice}" tcp dport { 53, 22 } accept comment "DNS TCP, SSH"
                  iifname "${lanDevice}" udp dport { 53, 123 } accept comment "DNS, NTP UDP"
                  iifname "${lanDevice}" icmp type { echo-request, echo-reply } accept

                  # Wireless input rules
                  ${wlanInputRules}

                  # Trusted interfaces (VPN, debug uplink)
                  ${trustedInputRules}

                  # Network/VLAN input rules (injected)
                  ${netFw.inputRules}

                  # Monitoring input rules (injected)
                  ${monFw.inputRules}

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
                }

                chain forward {
                  type filter hook forward priority 0; policy drop;

                  # Early accepts for established connections (critical for return traffic)
                  ct state established,related accept
                  ct state invalid drop

                  # LAN forwarding
                  iifname "${lanDevice}" oifname "${wan}" accept
                  iifname "${lanDevice}" oifname "${lanDevice}" accept

                  # Wireless forwarding
                  ${wlanForwardRules}

                  # Trusted interfaces
                  ${trustedForwardRules}

                  # Port forwarding rules
                  ${forwardRules}

                  # Network/VLAN forwarding rules (injected)
                  ${netFw.forwardRules}
                }
              '';
            };
            natV4 = {
              family = "ip";
              content = ''
                chain prerouting {
                  type nat hook prerouting priority -100;
                  ${dnatRules}
                }
                chain postrouting {
                  type nat hook postrouting priority 100;
                  oifname "${wan}" masquerade
                  ${netFw.natRules}
                }
              '';
            };
            forwardV4 = {
              family = "ip";
              content = ''
                chain forward {
                  type filter hook forward priority mangle;
                  tcp flags syn / syn,rst tcp option maxseg size set rt mtu
                }
              '';
            };
            forwardV6 = lib.mkIf cfg.ipv6.enable {
              family = "ip6";
              content = ''
                chain forward {
                  type filter hook forward priority mangle;
                  tcp flags syn / syn,rst tcp option maxseg size set rt mtu
                }
              '';
            };
            filterV6 = lib.mkIf cfg.ipv6.enable {
              family = "ip6";
              content = ''
                chain input {
                  type filter hook input priority 0; policy drop;

                  # Early accepts
                  iifname "lo" accept
                  ct state established,related accept
                  ct state invalid drop

                  # LAN input rules
                  iifname "${lanDevice}" tcp dport { 53, 22 } accept comment "DNS TCP, SSH"
                  iifname "${lanDevice}" udp dport 53 accept comment "DNS UDP"
                  iifname "${lanDevice}" icmpv6 type { echo-request, echo-reply, nd-neighbor-solicit, nd-neighbor-advert } accept comment "ICMPv6"

                  # Wireless input rules
                  ${wlanInputRulesV6}

                  # Trusted interfaces
                  ${trustedInputRules}

                  # WAN input rules
                  iifname "${wan}" icmpv6 type {
                    destination-unreachable, packet-too-big, time-exceeded,
                    parameter-problem, nd-router-advert, nd-neighbor-solicit,
                    nd-neighbor-advert
                  } accept
                  iifname "${wan}" udp dport dhcpv6-client udp sport dhcpv6-server accept
                }

                chain forward {
                  type filter hook forward priority 0; policy drop;

                  # Early accepts
                  ct state established,related accept
                  ct state invalid drop

                  # LAN forwarding
                  iifname "${lanDevice}" oifname "${wan}" accept

                  # Wireless forwarding
                  ${wlanForwardRules}

                  # Trusted interfaces
                  ${trustedForwardRules}
                }
              '';
            };
          };
        };
      };
    };
}
