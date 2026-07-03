# CUPS print broker (cups-browsed auto-discovery)
#
# Bridges AirPrint clients on PP-Net (br-main) to the Canon TR4500 on
# PP-IoT (br-iot, 10.0.20.50). Apple's Bonjour same-subnet check rejects
# the printer's off-subnet announcement reflected directly to br-main, so
# we run cupsd here and re-publish a queue with router IP as the endpoint.
#
# cups-browsed subscribes to local avahi (which sees the printer via the
# iot.mdns reflector), and at runtime auto-creates an IPP Everywhere queue
# mirroring the printer's TXT (URF/PWG-Raster/mopria-certified). No static
# `hardware.printers` block — earlier attempts hit lpadmin's "No IPP
# attributes" error on the TR4500 because lpadmin probes attrs at boot.
# Runtime queue creation sidesteps that.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  routerIp = config.my.router.lan.address;
in
{
  services.printing = {
    enable = true;
    listenAddresses = [
      "localhost:631"
      "${routerIp}:631" # only br-main; iot/wan never see CUPS
    ];
    allowFrom = [
      "localhost"
      "${config.my.router.lan.cidr}"
    ];
    browsing = true; # publish queues via Bonjour (cups-browsed + avahi)
    defaultShared = true;
    openFirewall = false; # router module owns nft input rules
    extraConf = ''
      BrowseLocalProtocols dnssd
      # Drop the _cups DNS-SD subtype. With it, macOS treats the queue as
      # "Bonjour Shared" and refuses to auto-install a driver (it expects a
      # pre-installed CUPS driver). Advertising only _print + _universal lets
      # macOS treat it as IPP Everywhere and auto-derive the PPD via
      # ipp2ppd — i.e., AirPrint behavior, no driver prompt.
      # Ref: https://github.com/OpenPrinting/cups/discussions/841
      BrowseDNSSDSubTypes _print,_universal
    '';
    browsedConf = ''
      BrowseRemoteProtocols dnssd
      BrowseLocalProtocols dnssd
      CreateIPPPrinterQueues All
      # Skip cupsd's own broker republish to break the feedback loop —
      # without this, cups-browsed sees `... @ pp-router1` on br-main and
      # creates a duplicate `<name>_pp_router1` queue chained to itself.
      BrowseFilter NOT name @ pp-router1
    '';
  };

  # cups.socket binds the router LAN IP (10.0.0.1:631), which systemd-networkd
  # assigns to br-main. On boot the socket races ahead of the address and dies
  # with "Cannot assign requested address", breaking AirPrint until a manual
  # restart. FreeBind (IP_FREEBIND) lets it bind the not-yet-present address.
  systemd.sockets.cups.socketConfig.FreeBind = true;

  # cups-browsed-created queues default to printer-is-shared=false (avoids
  # republishing loops when an upstream CUPS would re-discover). We need the
  # opposite — broker the queue onto br-main. Force shared=true post-start.
  systemd.services.cups-browsed = {
    postStart = ''
      for _ in $(seq 1 30); do
        if ${pkgs.cups}/bin/lpstat -e 2>/dev/null | grep -q .; then
          break
        fi
        sleep 1
      done
      for q in $(${pkgs.cups}/bin/lpstat -e 2>/dev/null); do
        ${pkgs.cups}/bin/lpadmin -p "$q" -o printer-is-shared=true || true
      done
    '';
  };

  # NixOS' cups pre-start only symlinks /var/lib/cups/cupsd.conf when missing,
  # so once cupsd self-rewrites the file (which it does on lpadmin/cupsctl),
  # subsequent rebuilds never replace it — stale config persists. Drop it
  # before cups starts so the pre-start re-symlinks to the latest store conf
  # (carrying our extraConf directives like BrowseDNSSDSubTypes).
  systemd.services.cups.preStart = lib.mkBefore ''
    if [ -e /var/lib/cups/cupsd.conf ] && [ ! -L /var/lib/cups/cupsd.conf ]; then
      rm -f /var/lib/cups/cupsd.conf
    fi
  '';

  # CUPS publishes its shared queue via avahi. The router's mdns module
  # defaults disable-user-service-publishing=yes, which causes
  # "DNS-SD registration ... failed: Not permitted" in cupsd logs.
  # userServices=true flips that to allow per-service publishing.
  services.avahi.publish.userServices = true;

  # Disable IPv6 NSS resolution for .local names. The Canon TR4500 only
  # advertises an IPv6 link-local A record (no global v6) for its mDNS
  # hostname. Without nssmdns6=false, getaddrinfo on `<printer>.local`
  # returns the link-local first, and cups-browsed's IPP probe to
  # `ipp://<printer>.local:631/ipp/print` fails (no zone-id, link-local
  # unreachable from a kernel-level connect()). Restricting NSS to IPv4 mDNS
  # forces cups-browsed onto 10.0.20.107 directly. avahi itself still
  # publishes/reflects v6 for everything else.
  services.avahi.nssmdns6 = lib.mkForce false;
}
