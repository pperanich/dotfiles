# Onboard a new external device to the pp-wg WireGuard network
#
# Usage: wg-add-peer <device-name> [--description "Device description"]
#
# Generates keypair, assigns IPv6 address, updates peers JSON,
# stores private key in sops, generates QR code, saves redacted config.
{
  lib,
  writeShellApplication,
  wireguard-tools,
  jq,
  qrencode,
  sops,
}:
(writeShellApplication {
  name = "wg-add-peer";

  runtimeInputs = [
    wireguard-tools
    jq
    qrencode
    sops
  ];

  text = ''
    # --- Configuration ---
    # Find repo root by walking up from CWD looking for flake.nix
    find_repo_root() {
      local dir="$PWD"
      while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/flake.nix" ]]; then
          echo "$dir"
          return 0
        fi
        dir="$(dirname "$dir")"
      done
      echo "Error: Could not find flake.nix in any parent directory" >&2
      return 1
    }

    REPO_ROOT=$(find_repo_root)
    PEERS_FILE="$REPO_ROOT/machines/pp-router1/wg-external-peers.json"
    DOCS_DIR="$REPO_ROOT/docs/wireguard"
    VARS_PREFIX_FILE="$REPO_ROOT/vars/per-machine/pp-router1/wireguard-network-pp-wg/prefix/value"
    VARS_PUBKEY_FILE="$REPO_ROOT/vars/per-machine/pp-router1/wireguard-keys-pp-wg/publickey/value"
    ENDPOINT="vpn.prestonperanich.com:51820"

    # --- Argument parsing ---
    DEVICE_NAME=""
    DESCRIPTION=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --description|-d)
          DESCRIPTION="$2"
          shift 2
          ;;
        --help|-h)
          echo "Usage: wg-add-peer <device-name> [--description \"Device description\"]"
          echo ""
          echo "Onboard a new external device to the pp-wg WireGuard network."
          echo ""
          echo "Arguments:"
          echo "  device-name    Short identifier (e.g., phone3, ipad1, laptop-guest)"
          echo "                 Used as the key in wg-external-peers.json and hostname"
          echo ""
          echo "Options:"
          echo "  -d, --description  Human-readable device description"
          echo "  -h, --help         Show this help message"
          echo ""
          echo "After running, deploy with: clan machines update pp-router1"
          exit 0
          ;;
        -*)
          echo "Error: Unknown option $1" >&2
          exit 1
          ;;
        *)
          if [[ -z "$DEVICE_NAME" ]]; then
            DEVICE_NAME="$1"
          else
            echo "Error: Unexpected argument $1" >&2
            exit 1
          fi
          shift
          ;;
      esac
    done

    if [[ -z "$DEVICE_NAME" ]]; then
      echo "Error: Device name required" >&2
      echo "Usage: wg-add-peer <device-name> [--description \"Device description\"]" >&2
      exit 1
    fi

    # Validate device name (alphanumeric + hyphens, used as JSON key and hostname)
    if ! [[ "$DEVICE_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      echo "Error: Device name must be lowercase alphanumeric with hyphens (e.g., phone3, ipad-work)" >&2
      exit 1
    fi

    # --- Read network parameters ---
    if [[ ! -f "$VARS_PREFIX_FILE" ]]; then
      echo "Error: WireGuard prefix not found at $VARS_PREFIX_FILE" >&2
      echo "Run 'clan vars generate pp-router1' first." >&2
      exit 1
    fi

    if [[ ! -f "$VARS_PUBKEY_FILE" ]]; then
      echo "Error: Router public key not found at $VARS_PUBKEY_FILE" >&2
      exit 1
    fi

    WG_PREFIX=$(cat "$VARS_PREFIX_FILE")
    ROUTER_PUBKEY=$(cat "$VARS_PUBKEY_FILE")

    # --- Check for duplicate device name ---
    if [[ -f "$PEERS_FILE" ]] && jq -e ".[\"$DEVICE_NAME\"]" "$PEERS_FILE" &>/dev/null; then
      echo "Error: Device '$DEVICE_NAME' already exists in $PEERS_FILE" >&2
      exit 1
    fi

    # --- Auto-assign next address suffix ---
    # Existing suffixes are hex strings like f001, f002, etc.
    # Find the highest and increment.
    if [[ -f "$PEERS_FILE" ]]; then
      HIGHEST=$(jq -r '.[].addressSuffix' "$PEERS_FILE" | sort | tail -1)
    else
      HIGHEST=""
    fi

    if [[ -z "$HIGHEST" ]]; then
      NEXT_SUFFIX="f001"
    else
      # Convert hex suffix to decimal, increment, convert back
      NEXT_DEC=$(( 16#$HIGHEST + 1 ))
      NEXT_SUFFIX=$(printf '%x' "$NEXT_DEC")
    fi

    ADDRESS="''${WG_PREFIX}::''${NEXT_SUFFIX}"
    echo "Device:  $DEVICE_NAME"
    echo "Address: ''${ADDRESS}/128"
    echo "Suffix:  $NEXT_SUFFIX"
    echo ""

    # --- Generate keypair ---
    PRIVATE_KEY=$(wg genkey)
    PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

    echo "Public key:  $PUBLIC_KEY"
    echo ""

    # --- Update peers JSON ---
    if [[ -f "$PEERS_FILE" ]]; then
      PEERS_JSON=$(cat "$PEERS_FILE")
    else
      PEERS_JSON="{}"
    fi

    NEW_PEER=$(jq -n \
      --arg name "''${DESCRIPTION:-$DEVICE_NAME}" \
      --arg pubkey "$PUBLIC_KEY" \
      --arg suffix "$NEXT_SUFFIX" \
      '{ name: $name, publicKey: $pubkey, addressSuffix: $suffix }')

    echo "$PEERS_JSON" | jq --arg key "$DEVICE_NAME" --argjson peer "$NEW_PEER" \
      '. + { ($key): $peer }' > "$PEERS_FILE"

    echo "Updated $PEERS_FILE"

    # --- Generate WireGuard config ---
    CONF_CONTENT="[Interface]
    PrivateKey = ''${PRIVATE_KEY}
    Address = ''${ADDRESS}/128

    [Peer]
    PublicKey = ''${ROUTER_PUBKEY}
    AllowedIPs = ''${WG_PREFIX}::/40
    Endpoint = ''${ENDPOINT}
    PersistentKeepalive = 25"

    # --- Save redacted config to docs ---
    mkdir -p "$DOCS_DIR"
    REDACTED_CONF="[Interface]
    # Private key stored in sops: wg-''${DEVICE_NAME}-private-key
    PrivateKey = <see sops/secrets.yaml: wg-''${DEVICE_NAME}-private-key>
    Address = ''${ADDRESS}/128

    [Peer]
    PublicKey = ''${ROUTER_PUBKEY}
    AllowedIPs = ''${WG_PREFIX}::/40
    Endpoint = ''${ENDPOINT}
    PersistentKeepalive = 25"

    echo "$REDACTED_CONF" > "$DOCS_DIR/''${DEVICE_NAME}.conf"
    echo "Saved redacted config to docs/wireguard/''${DEVICE_NAME}.conf"

    # --- Store private key in sops ---
    SOPS_KEY="wg-''${DEVICE_NAME}-private-key"
    SOPS_FILE="$REPO_ROOT/sops/secrets.yaml"

    echo "Storing private key in sops as ''\'''${SOPS_KEY}''\''..."
    sops set "$SOPS_FILE" "[\"''${SOPS_KEY}\"]" "\"''${PRIVATE_KEY}\""
    echo "Saved to $SOPS_FILE"

    # --- Display QR code ---
    echo ""
    echo "=== QR Code (scan with WireGuard app) ==="
    echo ""
    echo "$CONF_CONTENT" | qrencode -t ansiutf8
    echo ""

    # --- Summary ---
    echo "=== Done ==="
    echo ""
    echo "Deploy to router:"
    echo "  clan machines update pp-router1"
    echo ""
    echo "Then scan the QR code above with the WireGuard app on the device."
  '';
})
// {
  meta = with lib; {
    description = "Onboard a new external device to the pp-wg WireGuard network";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
