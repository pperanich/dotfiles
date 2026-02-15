# Create a Cloudflare Tunnel via API and store credentials in sops
#
# Usage: cf-tunnel-create <tunnel-name> --account-id <id>
#
# Creates tunnel via Cloudflare API, encrypts credentials with sops,
# and prints the tunnel UUID for use in Nix configuration.
# Requires CLOUDFLARE_API_TOKEN env var or cloudflare-api-token in sops.
{
  lib,
  writeShellApplication,
  curl,
  jq,
  sops,
  openssl,
}:
(writeShellApplication {
  name = "cf-tunnel-create";

  runtimeInputs = [
    curl
    jq
    sops
    openssl
  ];

  text = ''
    # --- Configuration ---
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
    CREDS_FILE="$REPO_ROOT/sops/cloudflared-tunnel.json"
    SOPS_FILE="$REPO_ROOT/sops/secrets.yaml"
    CF_API="https://api.cloudflare.com/client/v4"

    # Temp file for curl responses — cleaned up on exit
    TMPFILE=$(mktemp)
    trap 'rm -f "$TMPFILE"' EXIT

    # --- Helper: CF API call with proper error handling ---
    # Captures response body to TMPFILE, returns HTTP status code.
    # Usage: HTTP_CODE=$(cf_api GET "/path" [--data "$payload"])
    cf_api() {
      local method="$1" path="$2"
      shift 2
      curl -s -o "$TMPFILE" -w '%{http_code}' \
        -X "$method" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        "$CF_API$path" "$@"
    }

    # --- Argument parsing ---
    TUNNEL_NAME=""
    ACCOUNT_ID=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --account-id|-a)
          if [[ $# -lt 2 ]]; then
            echo "Error: --account-id requires a value" >&2
            exit 1
          fi
          ACCOUNT_ID="$2"
          shift 2
          ;;
        --help|-h)
          echo "Usage: cf-tunnel-create <tunnel-name> --account-id <cloudflare-account-id>"
          echo ""
          echo "Create a Cloudflare Tunnel via API and store credentials in sops."
          echo ""
          echo "Arguments:"
          echo "  tunnel-name        Name for the tunnel (e.g., homelab)"
          echo ""
          echo "Options:"
          echo "  -a, --account-id   Cloudflare account ID (required)"
          echo "  -h, --help         Show this help message"
          echo ""
          echo "Environment:"
          echo "  CLOUDFLARE_API_TOKEN   API token with Cloudflare Tunnel:Edit permission"
          echo "                         Falls back to cloudflare-api-token in sops/secrets.yaml"
          echo ""
          echo "Output:"
          echo "  - Encrypted credentials saved to sops/cloudflared-tunnel.json"
          echo "  - Prints tunnel UUID for use in Nix config"
          echo ""
          echo "After running, update machines/pp-router1/configuration.nix with the tunnel UUID,"
          echo "then deploy: clan machines update pp-router1"
          exit 0
          ;;
        -*)
          echo "Error: Unknown option $1" >&2
          exit 1
          ;;
        *)
          if [[ -z "$TUNNEL_NAME" ]]; then
            TUNNEL_NAME="$1"
          else
            echo "Error: Unexpected argument $1" >&2
            exit 1
          fi
          shift
          ;;
      esac
    done

    if [[ -z "$TUNNEL_NAME" ]]; then
      echo "Error: Tunnel name required" >&2
      echo "Usage: cf-tunnel-create <tunnel-name> --account-id <cloudflare-account-id>" >&2
      exit 1
    fi

    if [[ -z "$ACCOUNT_ID" ]]; then
      echo "Error: --account-id is required" >&2
      echo "Find it at: https://dash.cloudflare.com -> Account Home -> Account ID (right sidebar)" >&2
      exit 1
    fi

    # --- Resolve API token ---
    if [[ -z "''${CLOUDFLARE_API_TOKEN:-}" ]]; then
      echo "No CLOUDFLARE_API_TOKEN env var, extracting from sops..."
      if [[ ! -f "$SOPS_FILE" ]]; then
        echo "Error: $SOPS_FILE not found and CLOUDFLARE_API_TOKEN not set" >&2
        exit 1
      fi
      CLOUDFLARE_API_TOKEN=$(sops -d --extract '["cloudflare-api-token"]' "$SOPS_FILE" 2>/dev/null) || {
        echo "Error: Failed to decrypt cloudflare-api-token from $SOPS_FILE" >&2
        echo "Set CLOUDFLARE_API_TOKEN env var or ensure sops can decrypt secrets.yaml" >&2
        exit 1
      }
      export CLOUDFLARE_API_TOKEN
    fi

    # --- Verify token works ---
    echo "Verifying API token..."
    HTTP_CODE=$(cf_api GET "/user/tokens/verify")
    if [[ "$HTTP_CODE" -ne 200 ]]; then
      echo "Error: API token verification failed (HTTP $HTTP_CODE)." >&2
      jq -r '.errors[]?.message // "Unknown error"' "$TMPFILE" >&2 2>/dev/null
      echo "Required: Cloudflare Tunnel:Edit (account-scoped)" >&2
      exit 1
    fi

    TOKEN_STATUS=$(jq -r '.result.status' "$TMPFILE")
    if [[ "$TOKEN_STATUS" != "active" ]]; then
      echo "Error: API token status is '$TOKEN_STATUS', expected 'active'" >&2
      exit 1
    fi
    echo "Token verified."

    # --- Check for existing tunnel with same name ---
    # Use --data-urlencode with -G to safely encode the tunnel name in query params
    echo "Checking for existing tunnel named '$TUNNEL_NAME'..."
    HTTP_CODE=$(curl -s -o "$TMPFILE" -w '%{http_code}' -G \
      "$CF_API/accounts/$ACCOUNT_ID/cfd_tunnel" \
      --data-urlencode "name=$TUNNEL_NAME" \
      --data-urlencode "is_deleted=false" \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")

    if [[ "$HTTP_CODE" -ne 200 ]]; then
      echo "Error: Failed to list tunnels (HTTP $HTTP_CODE). Check account ID and token permissions." >&2
      jq -r '.errors[]?.message // "Unknown error"' "$TMPFILE" >&2 2>/dev/null
      exit 1
    fi

    EXISTING_COUNT=$(jq '.result | length' "$TMPFILE")
    if [[ "$EXISTING_COUNT" -gt 0 ]]; then
      EXISTING_ID=$(jq -r '.result[0].id' "$TMPFILE")
      echo "Error: Tunnel '$TUNNEL_NAME' already exists (ID: $EXISTING_ID)" >&2
      echo "Delete it first in the Cloudflare dashboard, or choose a different name." >&2
      exit 1
    fi

    # --- Generate tunnel secret ---
    # Capture the secret BEFORE sending to the API — CF does not echo it back.
    TUNNEL_SECRET=$(openssl rand -base64 32)

    # Build payload with jq to prevent JSON injection via tunnel name
    PAYLOAD=$(jq -n \
      --arg name "$TUNNEL_NAME" \
      --arg secret "$TUNNEL_SECRET" \
      '{name: $name, config_src: "local", tunnel_secret: $secret}')

    # --- Create tunnel ---
    echo "Creating tunnel '$TUNNEL_NAME'..."
    HTTP_CODE=$(cf_api POST "/accounts/$ACCOUNT_ID/cfd_tunnel" --data "$PAYLOAD")

    if [[ "$HTTP_CODE" -ne 200 ]]; then
      echo "Error: Failed to create tunnel (HTTP $HTTP_CODE):" >&2
      jq -r '.errors[]?.message // "Unknown error"' "$TMPFILE" >&2 2>/dev/null
      exit 1
    fi

    SUCCESS=$(jq -r '.success' "$TMPFILE")
    if [[ "$SUCCESS" != "true" ]]; then
      echo "Error: Tunnel creation failed:" >&2
      jq '.errors' "$TMPFILE" >&2
      exit 1
    fi

    TUNNEL_ID=$(jq -r '.result.id' "$TMPFILE")
    ACCOUNT_TAG=$(jq -r '.result.account_tag' "$TMPFILE")
    echo "Tunnel created: $TUNNEL_ID"

    # --- Cleanup trap: delete tunnel if credential storage fails ---
    cleanup_tunnel() {
      echo "Cleaning up: deleting orphaned tunnel $TUNNEL_ID from Cloudflare..." >&2
      cf_api DELETE "/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID" >/dev/null 2>&1 || true
      echo "Tunnel deleted. Re-run this script to try again." >&2
    }
    trap 'cleanup_tunnel; rm -f "$TMPFILE"' ERR

    # --- Build credentials JSON and encrypt directly (never plaintext on disk) ---
    # The credentials file format expected by cloudflared:
    #   { "AccountTag": "...", "TunnelID": "...", "TunnelSecret": "..." }
    CREDS_JSON=$(jq -n \
      --arg account "$ACCOUNT_TAG" \
      --arg tunnel_id "$TUNNEL_ID" \
      --arg secret "$TUNNEL_SECRET" \
      '{AccountTag: $account, TunnelID: $tunnel_id, TunnelSecret: $secret}')

    if [[ -f "$CREDS_FILE" ]]; then
      echo "Warning: $CREDS_FILE already exists, overwriting..."
    fi

    # Write plaintext then encrypt in-place — path must match .sops.yaml creation rule,
    # and binary format must match sops-nix's format = "binary" in the machine config.
    echo "$CREDS_JSON" > "$CREDS_FILE"
    sops -e -i --input-type binary --output-type binary "$CREDS_FILE" || {
      echo "Error: Failed to encrypt credentials file" >&2
      echo "Check that sops/.sops.yaml has a creation_rule for cloudflared-tunnel.json" >&2
      rm -f "$CREDS_FILE"
      cleanup_tunnel
      exit 1
    }

    # Credential storage succeeded — remove the cleanup traps
    trap - ERR
    trap 'rm -f "$TMPFILE"' EXIT

    echo "Encrypted credentials saved to $CREDS_FILE"

    # --- Summary ---
    echo ""
    echo "=== Tunnel Created ==="
    echo ""
    echo "  Tunnel ID:   $TUNNEL_ID"
    echo "  Tunnel Name: $TUNNEL_NAME"
    echo "  Credentials: $CREDS_FILE (sops-encrypted)"
    echo ""
    echo "=== Next Steps ==="
    echo ""
    echo "1. Update machines/pp-router1/configuration.nix:"
    echo "   tunnelId = \"$TUNNEL_ID\";"
    echo ""
    echo "2. Create CNAME record in Cloudflare dashboard:"
    echo "   vault.prestonperanich.com -> $TUNNEL_ID.cfargotunnel.com"
    echo ""
    echo "3. Add vaultwarden secrets to sops/secrets.yaml:"
    echo "   sops sops/secrets.yaml"
    echo "   # Add keys: vaultwarden-env, vaultwarden-admin-token"
    echo ""
    echo "4. Deploy:"
    echo "   clan machines update pp-router1"
  '';
})
// {
  meta = with lib; {
    description = "Create a Cloudflare Tunnel via API and store credentials in sops";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
