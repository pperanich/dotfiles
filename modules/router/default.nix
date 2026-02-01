_: {
  # Aggregated router module that enables everything
  # Sub-modules (core, network, firewall, dhcp, dns, hostapd, mdns) are auto-imported by import-tree
  flake.modules.nixos.router =
    { modules, ... }:
    {
      imports = with modules.nixos; [
        routerCoreInternal
        routerCore
        routerNetwork
        routerFirewall
        routerDhcp
        routerDns
        routerHostapd
        routerMdns
        routerSqm
        routerMonitoring
        routerNetworks # Unified VLAN + WiFi configuration
      ];
    };
}
