{
  config,
  lib,
  pkgs,
  ...
}:
# Added lib for mkForce
let
  # Define your interfaces
  wifiInterface = "wlp5s0"; # Your Wi-Fi interface
  ethernetInterface = "enp0s20f0u2u1"; # Ethernet interface connected to Orin
  bridgeInterface = "br0"; # Name for the new bridge interface
in {
  networking = {
    # 1. Define the bridge interface and add member interfaces
    bridges.${bridgeInterface}.interfaces = [
      wifiInterface
      ethernetInterface
    ];
    # 2. Configure the bridge interface to get an IP from your main network
    #    (e.g., your home Wi-Fi router's DHCP server)
    interfaces.${bridgeInterface}.useDHCP = true;
    # 7. Firewall:
    #    - The firewall rules previously defined for `ethernetInterface` (allowing DHCP/DNS
    #      to the NixOS machine) are no longer needed, as the NixOS machine isn't
    #      acting as a DHCP/DNS server for the Orin anymore.
    #    - Your main firewall (`networking.firewall.enable`) will now apply to traffic
    #      destined for the NixOS host itself via the `br0` interface's IP address.
    #    - Bridged traffic passes through at Layer 2 and is generally not affected by
    #      the host's iptables rules unless you use specific physdev matchers.
    #    - Ensure your main firewall allows DHCP client and typical traffic for the NixOS host
    #      itself on the br0 interface.
    firewall.enable = true; # Or false if you manage it externally/don't want it
    firewall.trustedInterfaces = [bridgeInterface]; # Optional: if you want to simplify rules for br0
  };

  # 3. Ensure member interfaces (Wi-Fi and Ethernet) do NOT have their own IP configurations.
  #    They will be part of the bridge.
  #    Using lib.mkForce to ensure any other configurations trying to set IPs are overridden.
  # networking.interfaces.${wifiInterface}.useDHCP = lib.mkForce false;
  # networking.interfaces.${wifiInterface}.ipv4.addresses = lib.mkForce [];
  # networking.interfaces.${wifiInterface}.ipv6.addresses = lib.mkForce [];
  # Depending on how wpa_supplicant or NetworkManager is configured for wlp5s0,
  # you might need to ensure it doesn't try to acquire an IP on wlp5s0 itself.
  # If using systemd-networkd for Wi-Fi (via networking.wireless options), it should be fine.
  # If using NetworkManager, ensure it doesn't manage wlp5s0 directly for IP once bridged,
  # or that it's configured to be part of the bridge without an IP.
  # One approach if NetworkManager tries to configure the IP on wlp5s0:
  # networking.networkmanager.unmanaged = [ "interface-name:${wifiInterface}" ];
  # However, NetworkManager also needs to handle the Wi-Fi connection itself.
  # A better way for NetworkManager is to let it manage the bridge:
  # Ensure NetworkManager is enabled if you rely on it for Wi-Fi connection:
  # networking.networkmanager.enable = true;
  # And then, you might need to tell NetworkManager that br0 is the primary interface,
  # and wlp5s0/enp0s20f0u2u1 are its ports. This can be complex with NixOS declarative config.
  # For simplicity, this config assumes systemd-networkd or basic scripts handle wlp5s0 connection
  # and that making it a bridge port will prevent it from getting its own IP.

  # networking.interfaces.${ethernetInterface}.useDHCP = lib.mkForce false;
  # networking.interfaces.${ethernetInterface}.ipv4.addresses = lib.mkForce [];
  # networking.interfaces.${ethernetInterface}.ipv6.addresses = lib.mkForce [];

  # 4. Disable IP Forwarding (not needed for a bridge, which is Layer 2)
  #    If it was enabled by the previous NAT setup, explicitly disable it.
  #    If it defaults to 0, this line is just for clarity.
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 0;
  # For IPv6, if you had forwarding enabled:
  # boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = lib.mkForce 0;

  # 5. Remove NAT configuration
  #    The entire 'networking.nat' block from your previous config should be removed.
  #    networking.nat.enable = false; # Or simply remove the block

  # 6. Remove dnsmasq service configuration
  #    The Orin will get DHCP and DNS from your main network's router.
  #    services.dnsmasq.enable = false; # Or simply remove the block

  # If your firewall was previously open due to `networking.firewall.enable = false;`
  # and you want to keep it that way, you can. If you enable it, ensure necessary
  # services on the NixOS host itself are allowed. For the bridging functionality,
  # the key is that traffic *through* the bridge is L2.

  # Optional: Spanning Tree Protocol (good practice for bridges to prevent loops)
  # networking.bridges.${bridgeInterface}.stp = true;

  # Ensure necessary packages for debugging are still available
  environment.systemPackages = with pkgs; [
    nettools # for ifconfig, route, brctl (from bridge-utils which is often part of nettools in effect)
    iptables # for checking host firewall rules (if any)
    bridge-utils # for brctl, to inspect the bridge
    # dnsmasq is no longer needed unless used for other purposes
  ];

  # If you are using NetworkManager to manage your Wi-Fi connection (wlp5s0):
  # This is a common scenario. Bridging a NetworkManager-controlled Wi-Fi client
  # interface declaratively in NixOS can be a bit involved because NetworkManager
  # likes to fully control its interfaces, including IP configuration.
  #
  # Option A (Simpler, if NetworkManager doesn't fight too much):
  # Hope that by assigning wlp5s0 to a bridge, NetworkManager still handles
  # the L2 Wi-Fi connection but doesn't assign an IP to wlp5s0. The bridge `br0`
  # then gets the IP via DHCP.
  #
  # Option B (More robust with NetworkManager):
  # You might need to configure the bridge *within NetworkManager*. This is less
  # declarative in `configuration.nix` and often involves `nmcli` commands or
  # NetworkManager connection profiles.
  # An alternative is to let NetworkManager manage `br0` and its ports.
  # services.NetworkManager.dispatcherScripts = [ ... ]; could be used for complex setups.
  #
  # Option C (Use systemd-networkd for Wi-Fi and bridging):
  # This can be more declaratively clean with NixOS.
  # networking.useNetworkd = true;
  # networking.networkd.enable = true;
  # Then configure wlp5s0 and the bridge using systemd-networkd options.
  # Example for systemd-networkd (you'd need to configure Wi-Fi credentials too):
  # systemd.network.networks."10-wifi" = {
  #   matchConfig.Name = wifiInterface;
  #   networkConfig.DHCP = "no"; # No IP on the wifi interface itself
  #   networkConfig.Bridge = bridgeInterface;
  #   # You would also need a wpa_supplicant setup for systemd-networkd
  #   # or use networking.wireless and ensure it doesn't assign IP.
  # };
  # systemd.network.networks."20-ethernet" = {
  #   matchConfig.Name = ethernetInterface;
  #   networkConfig.DHCP = "no";
  #   networkConfig.Bridge = bridgeInterface;
  # };
  # systemd.network.netdevs."30-bridge" = {
  #   netdevConfig = {
  #     Name = bridgeInterface;
  #     Kind = "bridge";
  #   };
  # };
  # systemd.network.networks."30-bridge-dhcp" = {
  #   matchConfig.Name = bridgeInterface;
  #   networkConfig.DHCP = "ipv4";
  # };

  # For now, the configuration at the top assumes a basic setup where declaring
  # the bridge and its ports is sufficient. If `wlp5s0` IP configuration fights
  # this, you'll need to refine how `wlp5s0` is managed.
}
