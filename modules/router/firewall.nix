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
      internal = cfg._internal;
      inherit (internal) lanSubnet;
      wan = cfg.wan.interface;
      inherit (internal) lanDevice;

      # Build trusted interface rules
      trustedInputRules = lib.concatMapStringsSep "\n" (
        iface: ''iifname "${iface}" accept''
      ) fwCfg.trustedInterfaces;

      trustedForwardRules = lib.concatMapStringsSep "\n" (iface: ''
        iifname "${iface}" oifname "${lanDevice}" accept
        iifname "${lanDevice}" oifname "${iface}" accept
        iifname "${iface}" oifname "${wan}" accept'') fwCfg.trustedInterfaces;

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
                  iifname "lo" accept
                  iifname "${lanDevice}" accept
                  ${trustedInputRules}
                  iifname "${wan}" ct state established,related accept
                  iifname "${wan}" ip protocol icmp accept
                  ${lib.optionalString (
                    fwCfg.openPorts.tcp != [ ]
                  ) ''iifname "${wan}" tcp dport { ${tcpPortsStr} } accept comment "Open TCP ports"''}
                  ${lib.optionalString (
                    fwCfg.openPorts.udp != [ ]
                  ) ''iifname "${wan}" udp dport { ${udpPortsStr} } accept comment "Open UDP ports"''}
                }
                chain forward {
                  type filter hook forward priority 0; policy drop;
                  iifname "${lanDevice}" oifname "${wan}" accept
                  iifname "${lanDevice}" oifname "${lanDevice}" accept
                  iifname "${wan}" oifname "${lanDevice}" ct state established,related accept
                  ${trustedForwardRules}
                  ${forwardRules}
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
                }
              '';
            };
            filterV6 = lib.mkIf cfg.ipv6.enable {
              family = "ip6";
              content = ''
                chain input {
                  type filter hook input priority 0; policy drop;
                  iifname "lo" accept
                  iifname "${lanDevice}" accept
                  ${trustedInputRules}
                  iifname "${wan}" ct state established,related accept
                  iifname "${wan}" icmpv6 type {
                    destination-unreachable, packet-too-big, time-exceeded,
                    parameter-problem, nd-router-advert, nd-neighbor-solicit,
                    nd-neighbor-advert
                  } accept
                  iifname "${wan}" udp dport dhcpv6-client udp sport dhcpv6-server accept
                }
                chain forward {
                  type filter hook forward priority 0; policy drop;
                  iifname "${lanDevice}" oifname "${wan}" accept
                  iifname "${wan}" oifname "${lanDevice}" ct state established,related accept
                  ${trustedForwardRules}
                }
              '';
            };
          };
        };
      };
    };
}
