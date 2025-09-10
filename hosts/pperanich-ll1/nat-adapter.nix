{
  config,
  pkgs,
  ...
}: let
  # Define your interfaces
  wifiInterface = "wlp5s0"; # Change if your Wi-Fi interface is different
  ethernetInterface = "enp0s20f0u2u1"; # Change if your Ethernet interface for Orin is different

  # Define the network for the Orin
  orinSubnetAddress = "192.168.2.1"; # IP of NixOS machine on the Orin's network
  orinSubnetPrefixLength = 24; # Corresponds to netmask 255.255.255.0
  orinDhcpRangeStart = "192.168.2.100";
  orinDhcpRangeEnd = "192.168.2.200";
  orinLeaseTime = "24h";

  # Define a local domain name for the Orin network
  localDomainName = "orin.lan";
  nixosRouterHostname = "nixos-gw"; # Hostname for your NixOS machine on this local LAN
in {
  # 1. Enable IP Forwarding
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # 2. Configure the Ethernet interface connected to the Orin AGX
  # This interface needs a static IP for dnsmasq to bind to and serve as gateway.
  networking = {
    interfaces.${ethernetInterface}.ipv4.addresses = [
      {
        address = orinSubnetAddress;
        prefixLength = orinSubnetPrefixLength;
      }
    ];
    # If using NetworkManager, you might want to tell it to leave this interface alone
    # or ensure it doesn't try to get DHCP on it.
    # Example:
    # networking.networkmanager.unmanaged = [ "interface-name:${ethernetInterface}" ];
    # Or ensure useDHCP is false (often default when static IP is assigned by NixOS modules)
    # networking.interfaces.${ethernetInterface}.useDHCP = false;

    # 3. Enable NAT (Network Address Translation)
    nat = {
      enable = true;
      externalInterface = wifiInterface;
      internalInterfaces = [ethernetInterface];
    };
    # networking.firewall.enable = false;
    firewall.interfaces.${ethernetInterface} = {
      # Allow DHCP (Dynamic Host Configuration Protocol) requests from Orin
      # dnsmasq listens on UDP port 67 for DHCP requests from clients (source port 68)
      allowedUDPPorts = [
        67 # DHCP Server port (bootps)
        53 # DNS port (dnsmasq also serves DNS)
      ];

      # Allow DNS over TCP as well (though UDP is more common for queries)
      allowedTCPPorts = [
        53 # DNS port
      ];
    };
  };

  # 4. Set up dnsmasq for DHCP and DNS on the Ethernet interface for Orin AGX
  services.dnsmasq = {
    enable = true;
    # Settings directly map to dnsmasq configuration options.
    # NixOS will convert this attrset to a dnsmasq.conf file.
    settings = {
      # ---- Listening and Interface Configuration ----
      # Listen on this specific interface for DHCP and DNS.
      # Dnsmasq will bind to the IP address configured on this interface.
      interface = ethernetInterface;
      # ---- DHCP Server Configuration ----
      # Format: <interface_if_different_from_global_interface_option>,<start-ip>,<end-ip>,<netmask_or_prefix>,<lease_time>
      # If the first part is missing, it applies to 'interface' or 'listen-address'.
      # We can omit the interface name in the string if 'interface' setting is used globally for this instance.
      # However, the example format uses it, so let's be explicit:
      dhcp-range = [
        "${ethernetInterface},${orinDhcpRangeStart},${orinDhcpRangeEnd},${orinLeaseTime}"
      ];
      # The router (gateway) for DHCP clients will automatically be ${orinSubnetAddress}
      # because dnsmasq is running on that IP on that interface.
      # If you needed to specify it explicitly (rarely needed when dnsmasq is the gateway):
      # dhcp-option = [ "option:router,${orinSubnetAddress}" ];

      # ---- DNS Server Configuration (for dnsmasq itself - upstream servers) ----
      # Dnsmasq will act as a caching DNS server for your Orin AGX.
      # Orin will get ${orinSubnetAddress} as its DNS server via DHCP.
      # These are the upstream servers dnsmasq will query.
      server = [
        "1.1.1.1" # Cloudflare
        "8.8.8.8" # Google
        "9.9.9.9" # Quad9
      ];
      no-resolv = true; # Do not read /etc/resolv.conf from the host NixOS system.

      # ---- Local DNS and Domain Configuration ----
      domain = localDomainName; # e.g., clients will get FQDNs like client.${localDomainName}
      local = "/${localDomainName}/"; # Queries for this domain are local and not forwarded
      expand-hosts = true; # Add domain to simple names in /etc/hosts & DHCP leases
      no-hosts = true;

      # Provide a DNS name for the NixOS router itself on this local network
      # This makes ${nixosRouterHostname}.${localDomainName} resolve to ${orinSubnetAddress}
      address = "/${nixosRouterHostname}.${localDomainName}/${orinSubnetAddress}";

      # ---- Other sensible defaults ----
      domain-needed = false; # Don't forward plain names (without dots)
      bogus-priv = true; # Don't forward reverse lookups for private IP ranges
      cache-size = 1000; # Increase DNS cache size
    };
  };

  # Ensure your main firewall settings don't block forwarded traffic unnecessarily.
  # `networking.nat` should handle the necessary FORWARD rules for NATted traffic.

  # If your Wi-Fi is managed by NetworkManager, ensure it's working correctly.
  # networking.networkmanager.enable = true; # Or whatever you use for Wi-Fi

  environment.systemPackages = with pkgs; [
    nettools # for ifconfig, route (debugging)
    iptables # for checking NAT/firewall rules
    dnsmasq # is already a dependency of services.dnsmasq
  ];
}
