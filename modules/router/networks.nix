_: {
  flake.modules.nixos.routerNetworks =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.router;
      netCfg = cfg.networks;
      internal = cfg._internal;
      wan = cfg.wan.interface;
      inherit (internal) lanDevice;
      enabled = cfg.enable && netCfg.enable;

      # Convert networks attrset to list with names
      networkList = lib.mapAttrsToList (name: net: net // { inherit name; }) netCfg.segments;

      # Networks with VLANs (exclude main LAN)
      vlanNetworks = lib.filter (n: n.vlan != null) networkList;

      # Networks with WiFi enabled, sorted: main LAN first (vlan=null), then by VLAN ID
      # This ensures the primary BSS is always the main network
      wifiNetworks =
        let
          filtered = lib.filter (n: n.wifi.enable) networkList;
          # Sort: null VLAN first, then by VLAN ID ascending
          sorted = lib.sort (
            a: b:
            if a.vlan == null then
              true
            else if b.vlan == null then
              false
            else
              a.vlan < b.vlan
          ) filtered;
        in
        sorted;

      # Get interface name for a network (used in firewall rules)
      # For VLAN networks, this is the dedicated bridge; for main LAN, it's the main bridge
      netIfaceName = net: if net.vlan != null then "br-${net.name}" else lanDevice;

      # Get router IP for a network
      netRouterIp = net: "${net.subnet}.1";

      # Get CIDR for a network
      netCidr = net: "${net.subnet}.0/24";

      # Get bridge name for WiFi - VLAN networks get their own bridge
      netBridge = net: if net.vlan != null then "br-${net.name}" else lanDevice;

      # Get VLAN interface name (the 802.1Q tagged interface on the main bridge)
      netVlanIface = net: "${lanDevice}.${toString net.vlan}";

      # Map security level to wpaKeyMgmt
      securityToKeyMgmt =
        security:
        {
          "wpa3" = "SAE";
          "wpa3-transition" = "SAE WPA-PSK";
          "wpa2" = "WPA-PSK";
          "open" = "NONE";
        }
        .${security} or "WPA-PSK";

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
            # ${net.name}: Trusted - full access to WAN, LAN, and all networks
            iifname "${iface}" oifname "${wan}" accept comment "${net.name} to WAN"
            ${lib.optionalString (net.vlan != null) ''
              iifname "${iface}" oifname "${lanDevice}" accept comment "${net.name} to LAN"
              iifname "${lanDevice}" oifname "${iface}" accept comment "LAN to ${net.name}"
            ''}
            ${lib.concatMapStringsSep "\n" (
              n:
              lib.optionalString (n.name != net.name && n.vlan != null) ''
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

      # Only generate VLAN-specific input/forward rules for VLAN networks
      allInputRules = lib.concatMapStringsSep "\n" mkInputRules vlanNetworks;
      allForwardRules = lib.concatMapStringsSep "\n" mkForwardRules vlanNetworks;
      allNatRules = lib.concatMapStringsSep "\n" (
        net: ''oifname "${wan}" ip saddr ${netCidr net} masquerade comment "NAT ${net.name}"''
      ) vlanNetworks;
    in
    {
      options.features.router.networks = {
        enable = lib.mkEnableOption "unified network segment definitions";

        segments = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule (_: {
              options = {
                vlan = lib.mkOption {
                  type = lib.types.nullOr (lib.types.ints.between 1 4094);
                  default = null;
                  example = 20;
                  description = "VLAN ID (1-4094). Null means main LAN (no VLAN tagging).";
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

                wifi = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Whether to broadcast a WiFi SSID for this network";
                  };

                  ssid = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                    example = "Home-IoT";
                    description = "WiFi network name (SSID)";
                  };

                  security = lib.mkOption {
                    type = lib.types.enum [
                      "wpa3"
                      "wpa3-transition"
                      "wpa2"
                      "open"
                    ];
                    default = "wpa2";
                    description = ''
                      WiFi security level:
                      - wpa3: WPA3-only (SAE)
                      - wpa3-transition: WPA3 + WPA2 compatibility
                      - wpa2: WPA2-only (most compatible)
                      - open: No encryption (not recommended)
                    '';
                  };

                  passwordSecret = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    example = "wifi_passphrase_iot";
                    description = "Name of sops secret containing the WiFi password";
                  };

                  clientIsolation = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Prevent WiFi clients from seeing each other (ap_isolate)";
                  };

                  roaming = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = ''
                      Enable 802.11r/k/v fast roaming for seamless band switching.
                      Disable for networks with simple IoT devices that may not support it.
                    '';
                  };
                };
              };
            })
          );
          default = { };
          example = lib.literalExpression ''
            {
              main = {
                subnet = "10.0.0";
                isolation = "none";
                wifi = {
                  enable = true;
                  ssid = "Home";
                  security = "wpa3-transition";
                  passwordSecret = "wifi_passphrase";
                };
              };
              iot = {
                vlan = 20;
                subnet = "10.0.20";
                isolation = "internet";
                allowAccessFrom = [ "main" ];
                wifi = {
                  enable = true;
                  ssid = "Home-IoT";
                  security = "wpa2";
                  passwordSecret = "wifi_passphrase_iot";
                };
              };
              guest = {
                vlan = 30;
                subnet = "10.0.30";
                isolation = "full";
                wifi = {
                  enable = true;
                  ssid = "Home-Guest";
                  security = "wpa2";
                  passwordSecret = "wifi_passphrase_guest";
                  clientIsolation = true;
                };
              };
            }
          '';
          description = "Network segment definitions combining VLAN and WiFi configuration";
        };
      };

      config = lib.mkIf enabled {
        # Validation assertions
        assertions =
          let
            vlanIds = map (n: n.vlan) (lib.filter (n: n.vlan != null) networkList);
            subnets = map (n: n.subnet) networkList;
            mainNetworks = lib.filter (n: n.vlan == null) networkList;
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
            # WiFi requires SSID
            (map (net: {
              assertion = !net.wifi.enable || net.wifi.ssid != "";
              message = "Network ${net.name}: wifi.ssid required when wifi.enable is true";
            }) networkList)
          ++
            # WiFi requires password (unless open)
            (map (net: {
              assertion = !net.wifi.enable || net.wifi.security == "open" || net.wifi.passwordSecret != null;
              message = "Network ${net.name}: wifi.passwordSecret required for secured WiFi";
            }) networkList)
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
            # At most one main network (no VLAN)
            {
              assertion = lib.length mainNetworks <= 1;
              message = "Only one network can be the main LAN (vlan = null)";
            }
          ];

        # Export network info for other modules
        features.router._internal.networks = lib.listToAttrs (
          map (net: {
            inherit (net) name;
            value = {
              inherit (net) vlan subnet isolation;
              interface = netIfaceName net;
              routerIp = netRouterIp net;
              cidr = netCidr net;
              bridge = netBridge net;
              inherit (net) wifi;
            };
          }) networkList
        );

        # Export WiFi networks for hostapd
        features.router._internal.wifiNetworks = map (net: {
          inherit (net) name;
          inherit (net.wifi)
            ssid
            security
            passwordSecret
            clientIsolation
            roaming
            ;
          bridge = netBridge net;
          wpaKeyMgmt = securityToKeyMgmt net.wifi.security;
        }) wifiNetworks;

        # Export firewall rules (always export, even if empty, for proper fallback handling)
        features.router._internal.networkFirewall = {
          inputRules = if vlanNetworks != [ ] then allInputRules else "";
          forwardRules =
            if vlanNetworks != [ ] then
              ''
                # Network-specific forwarding rules
                ${allForwardRules}
              ''
            else
              "";
          natRules = if vlanNetworks != [ ] then allNatRules else "";
        };

        # Create VLAN interfaces and bridges for each VLAN network
        systemd.network = lib.mkIf (vlanNetworks != [ ]) {
          netdevs =
            # VLAN interfaces (802.1Q tagged on main bridge)
            lib.listToAttrs (
              map (net: {
                name = "40-vlan-${net.name}";
                value = {
                  netdevConfig = {
                    Kind = "vlan";
                    Name = netVlanIface net;
                  };
                  vlanConfig = {
                    Id = net.vlan;
                  };
                };
              }) vlanNetworks
            )
            //
              # Bridge for each VLAN network (WiFi interfaces attach here)
              lib.listToAttrs (
                map (net: {
                  name = "30-br-${net.name}";
                  value = {
                    netdevConfig = {
                      Kind = "bridge";
                      Name = netBridge net;
                    };
                  };
                }) vlanNetworks
              );

          networks =
            # Attach VLANs to main bridge (creates the .20, .30 interfaces)
            {
              "10-lan" = {
                vlan = map netVlanIface vlanNetworks;
              };
            }
            //
              # Add VLAN interface to its dedicated bridge
              lib.listToAttrs (
                map (net: {
                  name = "45-vlan-${net.name}";
                  value = {
                    matchConfig.Name = netVlanIface net;
                    networkConfig = {
                      Bridge = netBridge net;
                      ConfigureWithoutCarrier = true;
                    };
                  };
                }) vlanNetworks
              )
            //
              # Configure bridge with IP address
              lib.listToAttrs (
                map (net: {
                  name = "50-br-${net.name}";
                  value = {
                    matchConfig.Name = netBridge net;
                    address = [ "${netRouterIp net}/24" ];
                    networkConfig = {
                      ConfigureWithoutCarrier = true;
                    };
                  };
                }) vlanNetworks
              );
        };

        # DHCP: Add VLAN bridge interfaces so Kea can serve these networks
        services.kea.dhcp4.settings.interfaces-config.interfaces = lib.mkIf (vlanNetworks != [ ]) (
          map (net: "br-${net.name}") vlanNetworks
        );

        # DHCP pools for VLAN networks
        services.kea.dhcp4.settings.subnet4 = lib.mkIf (vlanNetworks != [ ]) (
          map (net: {
            id = 1000 + net.vlan;
            subnet = netCidr net;
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
                data = "${net.name}.lan";
              }
            ];
          }) vlanNetworks
        );

        # DNS: Allow access from VLAN networks
        services.unbound.settings.server = lib.mkIf (vlanNetworks != [ ]) {
          interface = map netRouterIp vlanNetworks;
          access-control = map (net: "${netCidr net} allow") vlanNetworks;
        };

        # Chrony: Allow NTP from VLAN networks
        services.chrony.extraConfig = lib.mkIf (vlanNetworks != [ ]) (
          lib.concatMapStringsSep "\n" (net: "allow ${netCidr net}") vlanNetworks
        );
      };
    };
}
