# Dynamic DNS: sync Kea DHCP leases → Unbound local-data
#
# When a DHCP client gets a lease with a hostname, that hostname becomes
# resolvable as <hostname>.lan via Unbound. Records are kept in sync via
# a systemd path unit (inotify on the lease file) and a periodic timer fallback.
# The timer also re-syncs after Unbound restarts (partOf binding).
_: {
  flake.modules.nixos.routerDdns =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.features.router;
      dnsCfg = cfg.dns;
      enabled = cfg.enable && dnsCfg.enable && cfg.dhcp.enable && dnsCfg.ddns.enable;
      domain = cfg.dhcp.domainName; # "lan"
      leaseFile = "/var/lib/kea/dhcp4-leases.csv";
      trackingFile = "/run/kea-unbound-sync/records";
      unboundPkg = config.services.unbound.package;

      syncScript = pkgs.writeShellApplication {
        name = "kea-unbound-sync";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          LEASE_FILE="${leaseFile}"
          DOMAIN="${domain}"
          TRACKING_FILE="${trackingFile}"
          UNBOUND="${unboundPkg}/bin/unbound-control"
          NOW=$(date +%s)

          # Pre-flight: skip if Unbound isn't ready
          if ! "$UNBOUND" status >/dev/null 2>&1; then
            echo "[ddns] unbound not ready, skipping sync"
            exit 0
          fi

          # --- Parse active leases from Kea CSV ---
          # Columns: address,hwaddr,client_id,valid_lifetime,expire,subnet_id,
          #          fqdn_fwd,fqdn_rev,hostname,state,user_context,pool_id
          declare -A CURRENT_LEASES

          if [[ -f "$LEASE_FILE" ]]; then
            while IFS=',' read -r address _ _ _ expire _ _ _ hostname state _; do
              # Skip header and comments
              [[ "$address" =~ ^#|^address$ ]] && continue

              # Must have a hostname and be active (state 0)
              [[ -z "$hostname" || "$state" != "0" ]] && continue

              # Must not be expired (validate numeric first)
              if [[ "$expire" =~ ^[0-9]+$ ]] && [[ "$expire" -le "$NOW" ]]; then
                continue
              fi

              # Sanitize hostname: lowercase, alphanumeric + hyphens, strip invalid edges (RFC 952)
              hostname="''${hostname,,}"
              hostname="''${hostname//[^a-z0-9-]/}"
              hostname="''${hostname#"''${hostname%%[!-]*}"}"
              hostname="''${hostname%"''${hostname##*[!-]}"}"
              [[ -z "$hostname" ]] && continue

              # Last lease for a given hostname wins
              CURRENT_LEASES["$hostname"]="$address"
            done < "$LEASE_FILE"
          fi

          # --- Load previously synced records ---
          declare -A OLD_RECORDS
          if [[ -f "$TRACKING_FILE" ]]; then
            while IFS='=' read -r name addr; do
              [[ -n "$name" ]] && OLD_RECORDS["$name"]="$addr"
            done < "$TRACKING_FILE"
          fi

          # --- Add new / update changed records ---
          for hostname in "''${!CURRENT_LEASES[@]}"; do
            addr="''${CURRENT_LEASES[$hostname]}"
            fqdn="''${hostname}.''${DOMAIN}."

            if [[ "''${OLD_RECORDS[$hostname]:-}" != "$addr" ]]; then
              # Remove stale entry if IP changed
              if [[ -n "''${OLD_RECORDS[$hostname]:-}" ]]; then
                "$UNBOUND" local_data_remove "$fqdn" 2>/dev/null || true
              fi
              "$UNBOUND" local_data "$fqdn IN A $addr" || true
              echo "[ddns] $fqdn -> $addr"
            fi

            # Mark as processed
            unset "OLD_RECORDS[$hostname]" 2>/dev/null || true
          done

          # --- Remove records for expired/released leases ---
          for hostname in "''${!OLD_RECORDS[@]}"; do
            fqdn="''${hostname}.''${DOMAIN}."
            "$UNBOUND" local_data_remove "$fqdn" 2>/dev/null || true
            echo "[ddns] removed $fqdn"
          done

          # --- Persist current state (atomic write) ---
          TMPFILE="''${TRACKING_FILE}.tmp"
          : > "$TMPFILE"
          for hostname in "''${!CURRENT_LEASES[@]}"; do
            echo "''${hostname}=''${CURRENT_LEASES[$hostname]}" >> "$TMPFILE"
          done
          mv "$TMPFILE" "$TRACKING_FILE"

          echo "[ddns] synced ''${#CURRENT_LEASES[@]} lease(s)"
        '';
      };
    in
    {
      options.features.router.dns.ddns = {
        enable = lib.mkEnableOption "dynamic DNS updates from DHCP leases to Unbound";
      };

      config = lib.mkMerge [
        # Warning fires even when prerequisites are missing (outside mkIf enabled)
        {
          warnings = lib.optional (
            dnsCfg.ddns.enable && !(cfg.enable && dnsCfg.enable && cfg.dhcp.enable)
          ) "router: dns.ddns.enable has no effect without router, DNS, and DHCP all enabled";
        }

        (lib.mkIf enabled {
          # Domain consistency: DHCP domain must match DNS local zone
          assertions = [
            {
              assertion = "${cfg.dhcp.domainName}." == dnsCfg.localZone;
              message = "router: dns.ddns requires dhcp.domainName ('${cfg.dhcp.domainName}') to match dns.localZone ('${dnsCfg.localZone}')";
            }
          ];

          # Sync service — runs the script once per invocation
          systemd.services.kea-unbound-sync = {
            description = "Sync Kea DHCP leases to Unbound DNS";
            after = [
              "unbound.service"
              "kea-dhcp4-server.service"
            ];
            wants = [ "unbound.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe syncScript;
              RuntimeDirectory = "kea-unbound-sync";
              RuntimeDirectoryPreserve = true;

              # Sandboxing — script parses attacker-influenced DHCP hostnames
              ProtectSystem = "strict";
              ProtectHome = true;
              PrivateTmp = true;
              NoNewPrivileges = true;
            };
          };

          # Path unit — triggers sync when Kea writes the lease file
          systemd.paths.kea-unbound-sync = {
            description = "Watch Kea lease file for changes";
            wantedBy = [ "multi-user.target" ];
            pathConfig = {
              PathModified = leaseFile;
              Unit = "kea-unbound-sync.service";
            };
          };

          # Timer — periodic fallback (catches missed inotify events)
          # partOf: when Unbound restarts (losing dynamic records), this timer
          # also restarts and re-syncs within OnBootSec seconds
          systemd.timers.kea-unbound-sync = {
            description = "Periodic Kea→Unbound lease sync";
            wantedBy = [ "timers.target" ];
            partOf = [ "unbound.service" ];
            timerConfig = {
              OnBootSec = "30s";
              OnUnitActiveSec = "5min";
            };
          };
        })
      ];
    };
}
