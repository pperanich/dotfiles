_: {
  # Import all router sub-modules
  imports = [
    ./core.nix
    ./network.nix
    ./firewall.nix
    ./dhcp.nix
    ./dns.nix
  ];

  # Aggregated router module that enables everything
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
      ];
    };
}
