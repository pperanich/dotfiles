# Router Module Documentation

Comprehensive NixOS router module with VLAN segmentation, WiFi access point, firewall, DHCP, DNS, and traffic shaping.

## Overview

The router module (`modules/router/`) provides a complete home router solution built on NixOS. It's designed for devices like mini PCs with multiple NICs and WiFi cards.

### Features

- **Network Segmentation**: VLAN-based isolation (main, IoT, guest networks)
- **WiFi Access Point**: Multi-radio hostapd with WPA2/WPA3, 802.11r/k/v roaming
- **Firewall**: nftables with rate limiting, port forwarding, NAT
- **DHCP**: Kea DHCP server with static reservations
- **DNS**: Unbound recursive resolver with DNS-over-TLS
- **Traffic Shaping**: CAKE qdisc for bufferbloat reduction (SQM)
- **Monitoring**: ntopng traffic analysis
- **mDNS**: Avahi for `.local` device discovery

### Architecture

```
                    ┌─────────────────────────────────────────────────┐
                    │                  pp-router1                      │
Internet ──────────►│  WAN (enp1s0)                                   │
                    │       │                                          │
                    │       ▼                                          │
                    │  ┌─────────┐                                     │
                    │  │ nftables│ (NAT, firewall, rate limiting)      │
                    │  └────┬────┘                                     │
                    │       │                                          │
                    │       ▼                                          │
                    │  ┌─────────┐     ┌──────────┐    ┌──────────┐   │
                    │  │ br-lan  │────►│ br-iot   │───►│ br-guest │   │
                    │  │ 10.0.0.1│     │10.0.20.1 │    │10.0.30.1 │   │
                    │  └────┬────┘     └────┬─────┘    └────┬─────┘   │
                    │       │               │               │          │
                    │  ┌────┴────┐     ┌────┴────┐     ┌────┴────┐    │
                    │  │ wlan24  │     │wlan24_  │     │wlan24_  │    │
                    │  │ wlan5   │     │iot     │     │guest   │    │
                    │  │ enp2s0  │     │wlan5_  │     │wlan5_  │    │
                    │  └─────────┘     │iot     │     │guest   │    │
                    │                  └─────────┘     └─────────┘    │
                    └─────────────────────────────────────────────────┘
                              │               │               │
                              ▼               ▼               ▼
                         Main LAN        IoT Devices      Guest WiFi
                      (full access)   (internet only)   (isolated)
```

## Quick Start

### Minimal Configuration

```nix
# machines/my-router/configuration.nix
{ modules, ... }:
{
  imports = [ modules.nixos.router ];

  features.router = {
    enable = true;

    wan.interface = "enp1s0";
    lan.interface = "enp2s0";

    dhcp.enable = true;
    dns.enable = true;
  };
}
```

### Full Configuration Example

```nix
{ modules, config, ... }:
{
  imports = [ modules.nixos.router ];

  features.router = {
    enable = true;

    # Network interfaces
    wan.interface = "enp1s0";
    lan = {
      subnet = "10.0.0";
      interface = "enp2s0";
      dhcpRange = { start = 100; end = 200; };
    };

    # Enable services
    dhcp.enable = true;
    dns.enable = true;

    # Network segmentation with WiFi
    networks = {
      enable = true;
      segments = {
        main = {
          subnet = "10.0.0";
          isolation = "none";
          wifi = {
            enable = true;
            ssid = "PP-Net";
            security = "wpa3-transition";
            passwordSecret = "wifi_passphrase";
            roaming = true;
          };
        };
        iot = {
          vlan = 20;
          subnet = "10.0.20";
          isolation = "internet";
          allowAccessFrom = [ "main" ];
          wifi = {
            enable = true;
            ssid = "PP-IoT";
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
            ssid = "PP-Guest";
            security = "wpa2";
            passwordSecret = "wifi_passphrase_guest";
            clientIsolation = true;
          };
        };
      };
    };

    # WiFi radios
    hostapd = {
      enable = true;
      useNetworks = true;  # Auto-configure from networks.segments
      countryCode = "US";
      roaming.enable = true;
      radios = {
        radio24 = {
          interface = "wlan24";
          band = "2.4GHz";
          channel = 6;
          bridge = "br-lan";
          ieee80211n = true;
        };
        radio5 = {
          interface = "wlan5";
          band = "5GHz";
          channel = 36;
          bridge = "br-lan";
          ieee80211n = true;
          ieee80211ac = true;
          ieee80211ax = true;
          vhtOperChwidth = 1;
          vhtOperCentrFreqSeg0Idx = 42;
        };
      };
    };

    # Traffic shaping
    sqm = {
      enable = true;
      downloadMbps = 900;
      uploadMbps = 40;
    };

    # Monitoring
    monitoring.enable = true;

    # mDNS
    mdns.enable = true;

    # Static machines
    machines = [
      { name = "nas"; ip = 10; mac = "AA:BB:CC:DD:EE:01"; }
      { name = "server"; ip = 11; mac = "AA:BB:CC:DD:EE:02";
        portForwards = [{ port = 22; protocol = "tcp"; }]; }
    ];
  };
}
```

## Sub-Modules Reference

### Core (`core.nix`)

Base options and computed values used by all other modules.

| Option                  | Type | Default             | Description                                 |
| ----------------------- | ---- | ------------------- | ------------------------------------------- |
| `enable`                | bool | false               | Enable router functionality                 |
| `hostname`              | str  | networking.hostName | Router hostname                             |
| `wan.interface`         | str  | "enp1s0"            | WAN interface name                          |
| `wan.useDHCP`           | bool | true                | Use DHCP on WAN                             |
| `lan.subnet`            | str  | "10.0.0"            | LAN subnet (first 3 octets)                 |
| `lan.interface`         | str  | "enp2s0"            | Primary LAN interface                       |
| `lan.interfaces`        | list | []                  | Multiple LAN interfaces (creates bridge)    |
| `lan.dhcpRange.start`   | int  | 100                 | DHCP range start (last octet)               |
| `lan.dhcpRange.end`     | int  | 200                 | DHCP range end                              |
| `ipv6.enable`           | bool | true                | Enable IPv6                                 |
| `ipv6.ulaPrefix`        | str  | "fd00:1234:..."     | ULA prefix for IPv6                         |
| `machines`              | list | []                  | Static IP reservations with port forwarding |
| `services`              | list | []                  | Local DNS service entries                   |
| `upnp.enable`           | bool | false               | UPnP/NAT-PMP for automatic port forwarding  |
| `nginx.enable`          | bool | false               | Enable nginx reverse proxy                  |
| `debugUplink.enable`    | bool | false               | Debug uplink for development                |
| `debugUplink.interface` | str  | "enp2s0"            | Interface to use as debug uplink            |

#### Machine Definition

```nix
machines = [
  {
    name = "nas";           # Hostname (for DNS)
    ip = 10;                # Last octet (10.0.0.10)
    mac = "AA:BB:CC:DD:EE:01";
    portForwards = [
      { port = 22; protocol = "tcp"; }
      { port = 51820; protocol = "udp"; }
    ];
  }
];
```

---

### Networks (`networks.nix`)

Unified VLAN + WiFi network segment definitions.

| Option              | Type  | Default | Description                 |
| ------------------- | ----- | ------- | --------------------------- |
| `networks.enable`   | bool  | false   | Enable network segmentation |
| `networks.segments` | attrs | {}      | Network segment definitions |

#### Segment Options

| Option            | Type                | Default    | Description                       |
| ----------------- | ------------------- | ---------- | --------------------------------- |
| `vlan`            | int (1-4094) / null | null       | VLAN ID (null = main LAN)         |
| `subnet`          | str                 | required   | Subnet base (e.g., "10.0.20")     |
| `dhcpRange.start` | int                 | 100        | DHCP start                        |
| `dhcpRange.end`   | int                 | 200        | DHCP end                          |
| `isolation`       | enum                | "internet" | `none`, `internet`, `full`        |
| `allowAccessFrom` | list                | []         | Networks that can access this one |
| `allowAccessTo`   | list                | []         | Networks this can access          |

#### WiFi Options (per segment)

| Option                 | Type | Default | Description                               |
| ---------------------- | ---- | ------- | ----------------------------------------- |
| `wifi.enable`          | bool | false   | Broadcast SSID for this segment           |
| `wifi.ssid`            | str  | ""      | Network name                              |
| `wifi.security`        | enum | "wpa2"  | `wpa3`, `wpa3-transition`, `wpa2`, `open` |
| `wifi.passwordSecret`  | str  | null    | sops secret name for password             |
| `wifi.clientIsolation` | bool | false   | Prevent clients seeing each other         |
| `wifi.roaming`         | bool | true    | Enable 802.11r/k/v                        |

#### Isolation Levels

| Level      | WAN | Main LAN            | Other VLANs | Use Case        |
| ---------- | --- | ------------------- | ----------- | --------------- |
| `none`     | Yes | Yes                 | Yes         | Trusted devices |
| `internet` | Yes | Via allowAccessFrom | No          | IoT devices     |
| `full`     | Yes | No                  | No          | Guest network   |

---

### Hostapd (`hostapd.nix`)

WiFi access point configuration.

| Option                | Type  | Default | Description                           |
| --------------------- | ----- | ------- | ------------------------------------- |
| `hostapd.enable`      | bool  | false   | Enable WiFi AP                        |
| `hostapd.useNetworks` | bool  | false   | Auto-configure from networks.segments |
| `hostapd.countryCode` | str   | "US"    | Regulatory domain                     |
| `hostapd.radios`      | attrs | {}      | Radio configurations                  |

#### Radio Options

| Option                    | Type  | Default   | Description                                                    |
| ------------------------- | ----- | --------- | -------------------------------------------------------------- |
| `enable`                  | bool  | true      | Enable this radio                                              |
| `interface`               | str   | required  | Physical wireless interface                                    |
| `band`                    | enum  | required  | `2.4GHz`, `5GHz`, `6GHz`                                       |
| `ssid`                    | str   | ""        | Network name (optional if useNetworks)                         |
| `channel`                 | int   | 0         | Channel (0 = auto)                                             |
| `driver`                  | str   | "nl80211" | Hostapd driver                                                 |
| `bridge`                  | str   | null      | Bridge to attach to                                            |
| `bssid`                   | str   | null      | Explicit BSSID (required for 802.11r without bridge)           |
| `wpaPassphrase`           | str   | null      | WPA passphrase (mutually exclusive with file)                  |
| `wpaPassphraseFile`       | path  | null      | Path to password file                                          |
| `wpaKeyMgmt`              | str   | "WPA-PSK" | `SAE`, `WPA-PSK`, `SAE WPA-PSK`                                |
| `ieee80211w`              | int   | 0         | MFP/PMF (0=off, 1=optional, 2=required). Auto-set to 1 for SAE |
| `ieee80211n`              | bool  | true      | WiFi 4                                                         |
| `ieee80211ac`             | bool  | false     | WiFi 5 (5GHz only)                                             |
| `ieee80211ax`             | bool  | false     | WiFi 6                                                         |
| `htCapab`                 | str   | ""        | HT capabilities for 802.11n                                    |
| `vhtCapab`                | str   | ""        | VHT capabilities for 802.11ac                                  |
| `vhtOperChwidth`          | int   | 1         | VHT channel width (0=20/40, 1=80, 2=160, 3=80+80MHz)           |
| `vhtOperCentrFreqSeg0Idx` | int   | null      | VHT center frequency segment                                   |
| `extraSettings`           | attrs | {}        | Additional hostapd settings                                    |
| `additionalBSS`           | list  | []        | Additional SSIDs on this radio                                 |

#### WiFi 6 (HE) Options

When `ieee80211ax = true`, these additional options are available:

| Option           | Type | Default | Description                             |
| ---------------- | ---- | ------- | --------------------------------------- |
| `heSuBeamformer` | bool | true    | HE single-user beamformer               |
| `heSuBeamformee` | bool | true    | HE single-user beamformee               |
| `heMuBeamformer` | bool | false   | HE multi-user beamformer (MU-MIMO)      |
| `heBssColor`     | int  | 1       | HE BSS color for OBSS management (1-63) |

#### Roaming Options (802.11r/k/v)

| Option                          | Type | Default | Description                      |
| ------------------------------- | ---- | ------- | -------------------------------- |
| `roaming.enable`                | bool | false   | Enable fast roaming              |
| `roaming.mobilityDomain`        | str  | "a1b2"  | 4-hex-char domain ID             |
| `roaming.ft_over_ds`            | bool | false   | FT over Distribution System      |
| `roaming.ft_psk_generate_local` | bool | true    | Generate FT keys locally         |
| `roaming.ieee80211k`            | bool | true    | Radio Resource Management        |
| `roaming.ieee80211v`            | bool | true    | BSS Transition Management        |
| `roaming.bss_transition`        | bool | true    | BSS Transition Management frames |

---

### Firewall (`firewall.nix`)

nftables-based firewall with NAT.

| Option                               | Type | Default      | Description                       |
| ------------------------------------ | ---- | ------------ | --------------------------------- |
| `firewall.trustedInterfaces`         | list | []           | Interfaces with full access (VPN) |
| `firewall.openPorts.tcp`             | list | [80, 443]    | WAN TCP ports                     |
| `firewall.openPorts.udp`             | list | []           | WAN UDP ports                     |
| `firewall.rateLimiting.enable`       | bool | true         | DoS protection                    |
| `firewall.rateLimiting.icmpRate`     | str  | "10/second"  | ICMP rate limit                   |
| `firewall.rateLimiting.icmpBurst`    | int  | 50           | ICMP burst limit                  |
| `firewall.rateLimiting.newConnRate`  | str  | "100/second" | New connection limit              |
| `firewall.rateLimiting.newConnBurst` | int  | 200          | New connection burst limit        |

#### Default Rules

- LAN: DHCP, DNS, SSH, NTP, ICMP allowed
- WAN: Rate-limited, only open ports allowed
- Forwarding: LAN to WAN (NAT), established return traffic
- VLAN isolation enforced per network segment configuration

---

### DHCP (`dhcp.nix`)

Kea DHCP server.

| Option            | Type | Default | Description                 |
| ----------------- | ---- | ------- | --------------------------- |
| `dhcp.enable`     | bool | false   | Enable DHCP server          |
| `dhcp.leaseTime`  | int  | 86400   | Lease time in seconds (24h) |
| `dhcp.domainName` | str  | "lan"   | Domain for clients          |

Static reservations come from `machines` option. VLAN segments get their own pools automatically.

---

### DNS (`dns.nix`)

Unbound recursive resolver with DNS-over-TLS.

| Option                | Type | Default        | Description        |
| --------------------- | ---- | -------------- | ------------------ |
| `dns.enable`          | bool | false          | Enable DNS server  |
| `dns.upstreamServers` | list | Cloudflare DoT | Upstream resolvers |
| `dns.localZone`       | str  | "lan."         | Local zone name    |

Features:

- DNS-over-TLS to upstream (Cloudflare by default)
- Local zone for machines (`nas.lan`, `server.lan`)
- DNS rebinding protection
- Caching with prefetch

---

### SQM (`sqm.nix`)

Smart Queue Management for bufferbloat reduction using CAKE.

| Option             | Type | Default | Description                              |
| ------------------ | ---- | ------- | ---------------------------------------- |
| `sqm.enable`       | bool | false   | Enable traffic shaping                   |
| `sqm.downloadMbps` | int  | 900     | Download speed (set to 90-95% of actual) |
| `sqm.uploadMbps`   | int  | 40      | Upload speed (set to 90-95% of actual)   |
| `sqm.overhead`     | int  | 0       | Link layer overhead (0=Ethernet, 44=ATM) |

Test bufferbloat at [dslreports.com/speedtest](http://www.dslreports.com/speedtest) or [waveform.com/tools/bufferbloat](https://www.waveform.com/tools/bufferbloat).

---

### Monitoring (`monitoring.nix`)

ntopng traffic analysis.

| Option                     | Type | Default           | Description                                               |
| -------------------------- | ---- | ----------------- | --------------------------------------------------------- |
| `monitoring.enable`        | bool | false             | Enable ntopng                                             |
| `monitoring.httpPort`      | port | 3000              | Web UI port                                               |
| `monitoring.interfaces`    | list | auto              | Interfaces to monitor                                     |
| `monitoring.localNetworks` | list | ["{subnet}.0/24"] | Networks recognized as internal                           |
| `monitoring.dnsMode`       | enum | 1                 | DNS mode (0=local only, 1=all, 2=decode only, 3=disabled) |
| `monitoring.retentionDays` | int  | 30                | Data retention                                            |

Access at `http://router-ip:3000` from LAN.

---

### mDNS (`mdns.nix`)

Avahi for `.local` device discovery.

| Option                     | Type | Default | Description                 |
| -------------------------- | ---- | ------- | --------------------------- |
| `mdns.enable`              | bool | false   | Enable mDNS                 |
| `mdns.reflector`           | bool | true    | Forward between interfaces  |
| `mdns.extraInterfaces`     | list | []      | Additional interfaces       |
| `mdns.publish.enable`      | bool | true    | Publish local services      |
| `mdns.publish.addresses`   | bool | true    | Publish IP addresses        |
| `mdns.publish.domain`      | bool | true    | Publish domain name         |
| `mdns.publish.workstation` | bool | false   | Publish workstation service |

---

## Secrets Management

WiFi passwords and other secrets are managed via sops-nix:

```yaml
# sops/secrets.yaml
wifi_passphrase: "your-main-wifi-password"
wifi_passphrase_iot: "your-iot-password"
wifi_passphrase_guest: "your-guest-password"
```

Reference in config:

```nix
wifi.passwordSecret = "wifi_passphrase";
```

The module automatically reads from `config.sops.secrets.<name>.path`.

---

## Troubleshooting

### Check Service Status

```bash
# Core services
systemctl status kea-dhcp4-server unbound hostapd-radio24 hostapd-radio5

# View logs
journalctl -u hostapd-radio24 -f
journalctl -u kea-dhcp4-server -n 50
```

### Network Debugging

```bash
# Check interfaces
ip addr
ip link show master br-lan
brctl show

# Check VLAN bridges
ip link show br-iot
ip link show br-guest

# Check WiFi
iw dev
hostapd_cli -i wlan24 status

# Check firewall rules
nft list ruleset

# Check DHCP leases
cat /var/lib/kea/dhcp4-leases.csv

# Check DNS
unbound-control status
dig @localhost google.com
```

### Common Issues

| Issue                       | Cause                      | Solution                                    |
| --------------------------- | -------------------------- | ------------------------------------------- |
| WiFi clients can't get IP   | hostapd not bridged        | Check `bridge = "br-lan"` in radio config   |
| VLAN clients isolated wrong | Wrong isolation level      | Check `isolation` and `allowAccessFrom`     |
| No internet from VLAN       | Missing NAT rule           | Check `nft list chain ip natV4 postrouting` |
| Slow speeds                 | SQM misconfigured          | Set speeds to 90-95% of actual              |
| WiFi roaming fails          | Different mobility domains | Ensure same `mobilityDomain` on all APs     |

### Verify VLAN Setup

```bash
# Check VLAN interfaces exist
ip -d link show br-lan.20
ip -d link show br-iot

# Check bridge membership
bridge link show

# Test isolation (from IoT device)
ping 10.0.0.1     # Should work (router)
ping 10.0.0.10    # Should fail (main LAN device)
```

---

## File Structure

```
modules/router/
├── default.nix      # Aggregator - imports all sub-modules
├── core.nix         # Base options, computed values, machine definitions
├── network.nix      # systemd-networkd, bridges, kernel tuning
├── networks.nix     # Unified VLAN + WiFi segment definitions
├── firewall.nix     # nftables rules, NAT, port forwarding
├── dhcp.nix         # Kea DHCP server
├── dns.nix          # Unbound DNS resolver
├── hostapd.nix      # WiFi access point configuration
├── sqm.nix          # Traffic shaping (CAKE)
├── monitoring.nix   # ntopng traffic analysis
└── mdns.nix         # Avahi mDNS
```

---

## References

- [NixOS Networking](https://nixos.wiki/wiki/Networking)
- [hostapd documentation](https://w1.fi/hostapd/)
- [Kea DHCP](https://kea.isc.org/docs/kea-guide.html)
- [Unbound](https://nlnetlabs.nl/documentation/unbound/)
- [CAKE qdisc](https://www.bufferbloat.net/projects/codel/wiki/Cake/)
- [ntopng](https://www.ntop.org/products/traffic-analysis/ntopng/)
