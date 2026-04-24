# WireGuard VPN (pp-wg)

This directory contains configuration files for external WireGuard peers (non-clan devices like phones and tablets) and documentation for managing the pp-wg network.

## Overview

The `pp-wg` WireGuard network connects all clan-managed machines and external devices over an IPv6-only tunnel using ULA addresses derived from the instance name.

| Property          | Value                              |
| ----------------- | ---------------------------------- |
| **Instance name** | `pp-wg`                            |
| **Prefix**        | `fdb4:63fa:2:aa00::/40`            |
| **Controller**    | pp-router1 (`fdb4:63fa:2:aa00::1`) |
| **Endpoint**      | `vpn.prestonperanich.com:51820`    |
| **Protocol**      | IPv6 only (ULA addresses)          |

### Two Types of Peers

| Type               | Managed by                                                | Examples                       |
| ------------------ | --------------------------------------------------------- | ------------------------------ |
| **Clan peers**     | `clan-core` wireguard module (automatic keys + addresses) | pp-nas1, pp-ml1                |
| **External peers** | `wg-add-peer` tool + `wg-external-peers.json`             | phones, tablets, guest devices |

Clan peers are defined in `modules/flake-parts/clan.nix` under the `pp-wg` instance. External peers are defined in `machines/pp-router1/wg-external-peers.json`.

## Adding a New External Device

### Prerequisites

- Inside the `nix develop` shell (provides the `wg-add-peer` command)
- `SOPS_AGE_KEY` set (the devshell does this automatically from `~/.ssh/id_ed25519`)
- Router vars generated (`vars/per-machine/pp-router1/wireguard-network-pp-wg/` exists)

### Quick Start

```bash
# Enter devshell
nix develop

# Add a device
wg-add-peer ipad1 --description "Preston's iPad"
```

The tool handles everything:

1. Generates a WireGuard keypair
2. Auto-assigns the next available IPv6 address (e.g., `::f003`)
3. Adds the public key to `machines/pp-router1/wg-external-peers.json`
4. Stores the private key in `sops/secrets.yaml` (encrypted)
5. Saves a redacted config to `docs/wireguard/<device>.conf`
6. Displays a QR code for scanning

### After Running

1. **Deploy to the router** so it knows about the new peer:

   ```bash
   clan machines update pp-router1
   ```

2. **On the device**, open the WireGuard app and scan the QR code displayed by the tool. On iOS/Android: Add a tunnel > Create from QR code.

3. **Verify** by enabling the tunnel and accessing an internal service:

   ```
   https://ntopng.prestonperanich.com
   ```

### Command Reference

```
Usage: wg-add-peer <device-name> [--description "Device description"]

Arguments:
  device-name    Short identifier (e.g., phone3, ipad1, laptop-guest)
                 Used as the JSON key, hostname (<name>.pp-wg), and sops key name.
                 Must be lowercase alphanumeric with hyphens.

Options:
  -d, --description  Human-readable device description (stored in JSON)
  -h, --help         Show help message
```

### Examples

```bash
# Phone with description
wg-add-peer phone3 -d "Work iPhone"

# Tablet
wg-add-peer ipad1 -d "Preston's iPad"

# Guest laptop
wg-add-peer laptop-guest -d "Guest laptop"
```

## Adding a Clan-Managed Peer

For NixOS or Darwin machines managed by clan-core, add them to the inventory instead:

1. Edit `modules/flake-parts/clan.nix`:

   ```nix
   pp-wg = {
     module = { name = "wireguard"; input = "clan-core"; };
     roles = {
       controller.machines.pp-router1 = {
         settings.endpoint = "vpn.prestonperanich.com";
       };
       peer.machines = {
         pp-nas1 = { };
         # Add new machine here:
         pp-ll1 = { };
       };
     };
   };
   ```

2. Generate vars and deploy:

   ```bash
   clan vars generate <hostname>
   clan machines update pp-router1
   clan machines update <hostname>
   ```

## How Routing Works

External peers use split-tunnel routing:

- **AllowedIPs** is set to `fdb4:63fa:2:aa00::/40` (the WireGuard subnet only)
- Only traffic destined for the WireGuard network goes through the tunnel
- All other traffic (IPv4 and IPv6) uses the device's normal internet connection
- DNS queries use the device's normal DNS resolver (not the router)

To access internal services, Cloudflare DNS records for subdomains (e.g., `ntopng.prestonperanich.com`) point to the router's WireGuard AAAA address. The device resolves these via public DNS, sees the address is in the AllowedIPs range, and routes through the tunnel.

## File Layout

```
docs/wireguard/
  README.md                          # This file
  phone1.conf                        # Redacted config (private key in sops)
  phone2.conf                        # Redacted config (private key in sops)

machines/pp-router1/
  wg-external-peers.json             # Peer registry (public keys + addresses)
  configuration.nix                  # Reads peers.json, configures systemd-networkd

sops/secrets.yaml                    # Encrypted private keys (wg-<name>-private-key)

vars/per-machine/pp-router1/
  wireguard-network-pp-wg/prefix/    # Network prefix (fdb4:63fa:2:aa00)
  wireguard-keys-pp-wg/publickey/    # Router's WireGuard public key

pkgs/wg-add-peer/default.nix         # Nix package for the onboarding tool
```

## Peers JSON Schema

`machines/pp-router1/wg-external-peers.json`:

```json
{
  "<device-name>": {
    "name": "Human-readable description",
    "publicKey": "base64-encoded WireGuard public key",
    "addressSuffix": "hex suffix for IPv6 address (e.g., f001)"
  }
}
```

The address suffix is appended to the network prefix: `<prefix>::<suffix>/128`.

Address suffixes start at `f001` and auto-increment. The `f` prefix range (`f001`-`ffff`) is reserved for external peers to avoid collision with clan-assigned addresses.

## Recovering a Device Config

If a device needs to be reconfigured (e.g., new phone, factory reset):

1. Retrieve the private key from sops:

   ```bash
   sops -d --extract '["wg-<device-name>-private-key"]' sops/secrets.yaml
   ```

2. Reconstruct the config using the redacted `.conf` file in this directory, replacing the `PrivateKey` placeholder with the decrypted value.

3. Import into the WireGuard app manually or generate a new QR code:

   ```bash
   # Create a temp config with the real key, then:
   qrencode -t ansiutf8 < /tmp/recovered.conf
   ```

## Troubleshooting

### Device connects but can't reach services

- Verify the tunnel is active: check for a handshake in the WireGuard app
- Check that Cloudflare AAAA records point to `fdb4:63fa:2:aa00::1` (not the old prefix)
- Verify the peer is deployed on the router: `ssh root@10.0.0.1 "wg show pp-wg"`
- Check that Caddy is running: `ssh root@10.0.0.1 "systemctl status caddy"`

### "Address already in use" on router

The old WireGuard interface may still be running after a rename. Fix:

```bash
ssh root@10.0.0.1 "ip link delete <old-interface-name>"
ssh root@10.0.0.1 "systemctl restart systemd-networkd"
```

### QR code lost

Recover using the steps in "Recovering a Device Config" above.
