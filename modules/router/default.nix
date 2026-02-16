_: {
  # Aggregated router module that enables everything
  # Sub-modules (core, network, firewall, dhcp, dns, mdns) are auto-imported by import-tree
  flake.modules.nixos.router =
    { modules, ... }:
    {
      imports = with modules.nixos; [
        routerCoreInternal
        routerCore
        routerInterfaces
        routerFirewall
        routerDhcp
        routerDns
        routerDdns # Dynamic DNS: Kea DHCP leases → Unbound
        routerMdns
        routerSqm
        routerMonitoring
        routerVlans # VLAN network segmentation
        routerUnifi # Ubiquiti Unifi controller
        routerSsdpRelay # SSDP relay for cross-VLAN device discovery
      ];
    };
}
