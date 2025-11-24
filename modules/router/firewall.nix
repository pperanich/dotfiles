_: {
  flake.modules.nixos.routerFirewall =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.router;
      internal = cfg._internal;
      lanSubnet = internal.lanSubnet;
      wan = cfg.wan.interface;
      lanDevice = internal.lanDevice;

      # Build port forward rules from machines
      machinesByName = lib.listToAttrs (
        map (m: lib.nameValuePair m.name m) cfg.machines
      );

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
                  iifname "${wan}" ct state established,related accept
                  iifname "${wan}" ip protocol icmp accept
                  iifname "${wan}" tcp dport { 80, 443 } accept comment "HTTP/HTTPS"
                }
                chain forward {
                  type filter hook forward priority 0; policy drop;
                  iifname "${lanDevice}" oifname "${wan}" accept
                  iifname "${lanDevice}" oifname "${lanDevice}" accept
                  iifname "${wan}" oifname "${lanDevice}" ct state established,related accept
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
                }
              '';
            };
          };
        };
      };
    };
}
