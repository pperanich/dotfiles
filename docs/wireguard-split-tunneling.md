# WireGuard Split Tunneling with Network Namespaces

Route specific services through a WireGuard VPN while leaving the rest of the system on the default network path. This uses Linux network namespaces to create an isolated network environment that only VPN-bound services can see.

## Overview

Split tunneling confines a WireGuard tunnel inside a network namespace. Services that need the VPN explicitly opt in via systemd's `NetworkNamespacePath`; everything else is untouched.

```
┌──────────────────────────────────────────────────────────┐
│                        Host                              │
│                                                          │
│  ┌────────────────────┐    ┌──────────────────────────┐  │
│  │   Default Network  │    │  "vpn" Network Namespace  │  │
│  │                    │    │                           │  │
│  │  eth0 ─► internet  │    │  wg0 ─► VPN provider     │  │
│  │                    │    │                           │  │
│  │  caddy, ssh, ...   │    │  transmission, *arr, ...  │  │
│  │  (normal traffic)  │    │  (VPN-only traffic)       │  │
│  └────────────────────┘    └──────────────────────────┘  │
│          │                            │                   │
│          │  WireGuard socket lives    │                   │
│          │  HERE (can reach endpoint) │                   │
│          └────────────────────────────┘                   │
└──────────────────────────────────────────────────────────┘
```

### Key Properties

| Property            | Value                                                                |
| ------------------- | -------------------------------------------------------------------- |
| **Isolation**       | Services in the namespace can ONLY reach the network through the VPN |
| **No leaks**        | If the VPN drops, namespaced services lose all connectivity          |
| **Host unaffected** | Default route, DNS, and non-VPN services remain untouched            |
| **Declarative**     | Entire setup expressed in NixOS configuration                        |

### How It Differs from pp-wg

The existing [pp-wg WireGuard network](wireguard/README.md) connects clan machines over an IPv6 mesh for internal service access. Split tunneling is a different use case:

| Aspect      | pp-wg (Existing)                       | Split Tunnel (This Guide)                    |
| ----------- | -------------------------------------- | -------------------------------------------- |
| **Purpose** | Mesh connectivity between own machines | Route select services through a VPN provider |
| **Scope**   | All traffic to WG subnet               | All traffic from specific services           |
| **Method**  | `AllowedIPs` limited to ULA prefix     | Network namespace isolation                  |
| **Peers**   | Own machines and devices               | Commercial VPN provider endpoint             |

## NixOS Configuration

### Step 1: Network Namespace

Create a persistent namespace using a systemd oneshot service. The namespace must exist before WireGuard or any service that depends on it.

```nix
systemd.services.netns-vpn = {
  description = "VPN network namespace";
  before = [ "network.target" ];
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;

    ExecStart = pkgs.writeShellScript "netns-vpn-up" ''
      ${pkgs.iproute2}/bin/ip netns add vpn
      ${pkgs.iproute2}/bin/ip netns exec vpn \
        ${pkgs.iproute2}/bin/ip link set lo up
    '';

    ExecStop = "${pkgs.iproute2}/bin/ip netns del vpn";
  };
};
```

### Step 2: WireGuard in the Namespace

Use `networking.wireguard.interfaces` with `interfaceNamespace` to create the WireGuard interface in the root namespace (so it can reach the VPN endpoint) and then move it into the `vpn` namespace.

```nix
networking.wireguard.interfaces.wg-vpn = {
  # Create in root namespace, move to "vpn"
  interfaceNamespace = "vpn";

  ips = [ "10.64.0.2/32" ];
  privateKeyFile = config.sops.secrets.wg-vpn-private-key.path;

  # Routes inside the namespace — 0.0.0.0/0 forces ALL traffic through VPN
  allowedIPsAsRoutes = true;

  preSetup = ''
    # Ensure namespace exists (idempotent)
    ${pkgs.iproute2}/bin/ip netns add vpn 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip netns exec vpn \
      ${pkgs.iproute2}/bin/ip link set lo up
  '';

  peers = [
    {
      publicKey = "VPN_PROVIDER_PUBLIC_KEY";
      endpoint = "vpn-server.example.com:51820";
      allowedIPs = [ "0.0.0.0/0" "::/0" ];
      persistentKeepalive = 25;
    }
  ];
};
```

**Important**: The NixOS WireGuard module does NOT create the namespace — it only moves the interface into a pre-existing one. The `preSetup` script handles creation as a safety net, but the `netns-vpn` service from Step 1 is the primary owner.

### Step 3: DNS Inside the Namespace

Processes in the namespace cannot reach the host's DNS resolver. You must provide one explicitly.

**Option A: Static resolv.conf** (simplest)

```nix
# Write a resolv.conf for the namespace
environment.etc."netns/vpn/resolv.conf".text = ''
  nameserver 10.64.0.1
'';
```

When using `ip netns exec`, Linux automatically bind-mounts `/etc/netns/<name>/resolv.conf` over `/etc/resolv.conf`. For systemd services using `NetworkNamespacePath`, you must also add a bind mount (see Step 4).

**Option B: Local forwarder** (better for caching / DNS leak prevention)

```nix
systemd.services.dnsmasq-vpn = {
  description = "DNS forwarder for VPN namespace";
  bindsTo = [ "wireguard-wg-vpn.service" ];
  after = [ "wireguard-wg-vpn.service" ];
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    NetworkNamespacePath = "/var/run/netns/vpn";
    ExecStart = ''
      ${pkgs.dnsmasq}/bin/dnsmasq \
        --no-daemon \
        --server=10.64.0.1 \
        --listen-address=127.0.0.1 \
        --port=53 \
        --no-resolv \
        --cache-size=1000
    '';
  };
};

# Point namespace DNS at the local forwarder
environment.etc."netns/vpn/resolv.conf".text = ''
  nameserver 127.0.0.1
'';
```

### Step 4: Bind a Service to the Namespace

Use `NetworkNamespacePath` to run a service inside the VPN namespace. The service can only communicate through the WireGuard tunnel.

```nix
systemd.services.transmission = {
  description = "Transmission BitTorrent client (VPN)";

  bindsTo = [ "wireguard-wg-vpn.service" ];
  after = [ "wireguard-wg-vpn.service" ];
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    NetworkNamespacePath = "/var/run/netns/vpn";

    # DNS: bind-mount the namespace resolv.conf
    BindReadOnlyPaths = [
      "/etc/netns/vpn/resolv.conf:/etc/resolv.conf"
    ];

    ExecStart = "${pkgs.transmission}/bin/transmission-daemon --foreground";
    User = "transmission";
    Group = "transmission";
  };
};
```

**Key systemd properties**:

| Property               | Purpose                                                            |
| ---------------------- | ------------------------------------------------------------------ |
| `NetworkNamespacePath` | Runs the service inside the specified network namespace            |
| `BindReadOnlyPaths`    | Bind-mounts the VPN resolv.conf so DNS resolves through the tunnel |
| `bindsTo`              | Stops the service if WireGuard goes down (kill switch)             |
| `after`                | Ensures WireGuard is ready before the service starts               |

### Step 5: Expose the Service to the Host (Optional)

Services inside the namespace are unreachable from the host by default. Use a socket proxy to bridge traffic from the host network into the namespace.

```nix
# Socket that listens on the host network
systemd.sockets.transmission-proxy = {
  description = "Proxy to Transmission in VPN namespace";
  wantedBy = [ "sockets.target" ];
  listenStreams = [ "9091" ];  # Transmission web UI port
};

# Proxy service that joins the namespace
systemd.services.transmission-proxy = {
  description = "Socket proxy to Transmission";
  requires = [ "transmission.service" "transmission-proxy.socket" ];
  after = [ "transmission.service" ];

  unitConfig.JoinsNamespaceOf = "transmission.service";

  serviceConfig = {
    ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:9091";
    PrivateNetwork = true;
  };
};
```

With this, `http://localhost:9091` on the host reaches Transmission running inside the VPN namespace.

## Service Ordering

The dependency chain ensures correct startup and clean teardown:

```
netns-vpn  ─►  wireguard-wg-vpn  ─►  dnsmasq-vpn  ─►  transmission
(namespace)      (VPN tunnel)         (DNS inside)      (application)
                                                            │
                                              transmission-proxy.socket
                                              (host-side access)
```

`bindsTo` propagates stop events backward: if WireGuard goes down, all dependent services stop immediately (kill switch behavior).

## Secrets

Store the WireGuard private key in sops, following the [existing secrets pattern](secrets-and-key-management.md):

```nix
sops.secrets.wg-vpn-private-key = {
  sopsFile = lib.my.relativeToRoot "sops/secrets.yaml";
  owner = "root";
  group = "root";
  mode = "0400";
};
```

Add the key to `sops/secrets.yaml`:

```bash
sops sops/secrets.yaml
# Add: wg-vpn-private-key: "<base64-encoded-private-key>"
```

## Verifying the Setup

### Confirm Namespace Exists

```bash
ip netns list
# Expected: vpn (id: N)
```

### Confirm WireGuard Is in the Namespace

```bash
# Should show wg-vpn interface with IP
ip netns exec vpn ip addr show wg-vpn

# Should show active handshake
ip netns exec vpn wg show
```

### Confirm Traffic Routes Through VPN

```bash
# Public IP inside namespace (should be VPN provider IP)
ip netns exec vpn curl -s ifconfig.me

# Public IP on host (should be ISP IP)
curl -s ifconfig.me

# These two IPs MUST be different
```

### Confirm DNS Works Inside Namespace

```bash
# Should resolve through VPN DNS
ip netns exec vpn nslookup google.com

# Check which resolver is being used
ip netns exec vpn cat /etc/resolv.conf
```

### Confirm Service Is Namespaced

```bash
# Find the service's PID
systemctl show -p MainPID transmission.service

# Verify it sees the VPN interface, not the host's
nsenter -t $(systemctl show -p MainPID --value transmission.service) -n ip addr
# Should show wg-vpn and lo only — no eth0, no br-lan
```

### Confirm Kill Switch Works

```bash
# Stop WireGuard
systemctl stop wireguard-wg-vpn

# Service should be stopped too (bindsTo)
systemctl is-active transmission.service
# Expected: inactive

# Restart
systemctl start wireguard-wg-vpn
```

## Monitoring Traffic

### Packet Capture

```bash
# Encrypted WireGuard packets (on physical interface)
tcpdump -i eth0 udp port 51820 -c 20

# Decrypted traffic inside namespace
ip netns exec vpn tcpdump -i wg-vpn -c 20

# DNS queries inside namespace (check for leaks)
ip netns exec vpn tcpdump -i any port 53 -n
```

### Connection Monitoring

```bash
# Active connections in namespace
ip netns exec vpn ss -tnp

# Listening sockets in namespace
ip netns exec vpn ss -tulpn

# Routing table
ip netns exec vpn ip route show
# Expected: default dev wg-vpn (everything goes through VPN)
```

### Continuous WireGuard Status

```bash
# Live transfer stats and handshake age
watch -n 2 'ip netns exec vpn wg show'
```

### Connection Tracking

```bash
# All tracked connections through the VPN
ip netns exec vpn conntrack -L 2>/dev/null

# Live connection events
ip netns exec vpn conntrack -E 2>/dev/null
```

## Troubleshooting

### Service can't resolve DNS

| Symptom                   | Cause                                        | Fix                                                               |
| ------------------------- | -------------------------------------------- | ----------------------------------------------------------------- |
| `SERVFAIL` on all queries | resolv.conf not bind-mounted                 | Add `BindReadOnlyPaths` for `/etc/resolv.conf` (see Step 4)       |
| Resolves but wrong IPs    | DNS leaking to host resolver via nscd socket | Disable nscd: `services.nscd.enable = false;`                     |
| Timeout on DNS queries    | VPN provider DNS unreachable                 | Check `ip netns exec vpn ping <dns-ip>`, verify peer `allowedIPs` |

### Service starts but has no network

| Symptom                   | Cause                          | Fix                                                            |
| ------------------------- | ------------------------------ | -------------------------------------------------------------- |
| `Network unreachable`     | WireGuard not in namespace     | Check `ip netns exec vpn ip link` — should show `wg-vpn`       |
| `No route to host`        | Missing default route          | Check `ip netns exec vpn ip route` — need `default dev wg-vpn` |
| Service ignores namespace | Missing `NetworkNamespacePath` | Verify with `nsenter -t <PID> -n ip addr`                      |

### WireGuard handshake fails

| Symptom                | Cause                          | Fix                                                     |
| ---------------------- | ------------------------------ | ------------------------------------------------------- |
| No handshake ever      | Endpoint unreachable from host | `ping vpn-server.example.com` from host (NOT namespace) |
| Handshake then silence | `allowedIPs` too restrictive   | Ensure `0.0.0.0/0` is in peer's `allowedIPs`            |
| Intermittent drops     | NAT timeout                    | Set `persistentKeepalive = 25`                          |

### Cannot reach namespaced service from host

| Symptom            | Cause                    | Fix                                                      |
| ------------------ | ------------------------ | -------------------------------------------------------- |
| Connection refused | Socket proxy not running | Check `systemctl status transmission-proxy.socket`       |
| Connection timeout | Service not listening    | `ip netns exec vpn ss -tulpn` to verify service is bound |

## Comparison of Approaches

For reference, here are the three main split-tunneling strategies. This guide covers Option 1.

| Approach                       | Isolation | Complexity | Use Case                       |
| ------------------------------ | --------- | ---------- | ------------------------------ |
| **1. Network namespaces**      | Strong    | Medium     | Per-service VPN (this guide)   |
| **2. Limited AllowedIPs**      | Weak      | Low        | Route to specific subnets only |
| **3. fwmark + policy routing** | Medium    | High       | Route by UID, cgroup, or port  |

## References

- [WireGuard Network Namespaces](https://www.wireguard.com/netns/) — Official docs on the namespace pattern
- [NixOS WireGuard Module Source](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/wireguard.nix) — `interfaceNamespace` and `socketNamespace` implementation
- [mth.st: NixOS WireGuard Netns](https://mth.st/blog/nixos-wireguard-netns/) — Blog post with `netns@` template pattern
- [VPN-Confinement](https://github.com/Maroka-chan/VPN-Confinement) — NixOS module for VPN-confined services
- [systemd.exec(5)](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#NetworkNamespacePath=) — `NetworkNamespacePath` reference
- [pp-wg WireGuard Network](wireguard/README.md) — Existing mesh VPN in this repo
