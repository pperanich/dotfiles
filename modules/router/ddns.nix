# Dynamic DNS: sync Kea DHCP leases → Unbound local-data
#
# When a DHCP client gets a lease with a hostname, that hostname becomes
# resolvable as <hostname>.home.arpa via Unbound. Records are kept in sync via
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
      cfg = config.my.router;
      dnsCfg = cfg.dns;
      enabled = cfg.enable && dnsCfg.enable && cfg.dhcp.enable && dnsCfg.ddns.enable;
      domain = cfg.dhcp.domainName; # "home.arpa"
      domainLower = lib.toLower domain;
      leaseFile = "/var/lib/kea/dhcp4-leases.csv";
      trackingFile = "/run/kea-unbound-sync/records";
      unboundPkg = config.services.unbound.package;

      allStaticReservations = cfg._internal.staticHostReservations or [ ];

      extraLocalHostnames =
        let
          extractHost =
            raw:
            let
              tok = lib.removeSuffix "." (lib.toLower (builtins.head (lib.splitString " " (lib.trim raw))));
            in
            if lib.hasSuffix ".${domainLower}" tok then
              builtins.head (lib.splitString "." (lib.removeSuffix ".${domainLower}" tok))
            else if !(lib.hasInfix "." tok) then
              tok
            else
              null;
        in
        lib.filter (h: h != null && h != "") (
          map extractHost dnsCfg.extraLocalData ++ map (s: extractHost s.name) cfg.services
        );

      protectedHostnames = lib.unique (
        [
          "router"
          "gateway"
          "unifi"
          "wpad"
          "isatap"
          "localhost"
          (lib.toLower cfg.hostname)
          (lib.toLower config.networking.hostName)
        ]
        ++ map (r: r.hostname) allStaticReservations
        ++ extraLocalHostnames
        ++ lib.optionals cfg.networks.enable (map lib.toLower (lib.attrNames cfg.networks.segments))
        ++ map lib.toLower dnsCfg.ddns.extraBlockedHostnames
      );

      subnetZoneEntries =
        if cfg.networks.enable then
          lib.mapAttrsToList (
            segName: seg:
            let
              zone =
                if seg.isolation == "none" then
                  domain
                else if dnsCfg.ddns.isolatedSegmentMode == "subdomain" then
                  "${lib.toLower segName}.${domain}"
                else
                  "__EXCLUDE__";
            in
            "[${lib.escapeShellArg seg.subnet}]=${lib.escapeShellArg zone}"
          ) cfg.networks.segments
        else
          [ "[${lib.escapeShellArg cfg.lan.subnet}]=${lib.escapeShellArg domain}" ];

      protectedHostnameEntries = map (h: "[${lib.escapeShellArg h}]=1") protectedHostnames;

      staticReservationIpEntries = map (
        r: "[${lib.escapeShellArg r.hostname}]=${lib.escapeShellArg r.ip}"
      ) allStaticReservations;

      syncScript = pkgs.writeShellApplication {
        name = "kea-unbound-sync";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          LEASE_FILE="${leaseFile}"
          DOMAIN="${domain}"
          TRACKING_FILE="${trackingFile}"
          UNBOUND="${unboundPkg}/bin/unbound-control"
          NOW=$(date +%s)

          declare -A PROTECTED_HOSTS=(
            ${lib.concatStringsSep "\n  " protectedHostnameEntries}
          )
          declare -A RESERVED_IPS=(
            ${lib.concatStringsSep "\n  " staticReservationIpEntries}
          )
          declare -A SUBNET_ZONES=(
            ${lib.concatStringsSep "\n  " subnetZoneEntries}
          )

          # Pre-flight: skip if Unbound isn't ready
          if ! "$UNBOUND" status >/dev/null 2>&1; then
            echo "[ddns] unbound not ready, skipping sync"
            exit 0
          fi

          # --- Parse active leases from Kea CSV ---
          # Columns: address,hwaddr,client_id,valid_lifetime,expire,subnet_id,
          #          fqdn_fwd,fqdn_rev,hostname,state,user_context,pool_id
          #
          # Kea uses LFC (Lease File Cleanup) which splits data across two files:
          #   .csv.2  = consolidated leases from last LFC run
          #   .csv    = append-only journal of changes since last LFC
          # We read .csv.2 first, then .csv on top so recent changes win.
          declare -A CURRENT_LEASES=()

          for lf in "''${LEASE_FILE}.2" "$LEASE_FILE"; do
            [[ -f "$lf" ]] || continue
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

              # Reject protected/static hostnames so dynamic leases cannot hijack them
              if [[ -n "''${PROTECTED_HOSTS[$hostname]:-}" ]]; then
                if [[ "''${RESERVED_IPS[$hostname]:-}" == "$address" ]]; then
                  # Legitimate Kea lease for a static reservation (already in static local-data)
                  continue
                fi
                echo "[ddns] REJECTED protected hostname '$hostname' claimed by lease $address" >&2
                continue
              fi

              # Scope zone by lease subnet / segment isolation
              subnet_prefix="''${address%.*}"
              target_zone="''${SUBNET_ZONES[$subnet_prefix]:-}"
              if [[ -z "$target_zone" || "$target_zone" == "__EXCLUDE__" ]]; then
                continue
              fi

              fqdn="''${hostname}.''${target_zone}."

              # Last lease for a given FQDN within its authorized zone wins
              CURRENT_LEASES["$fqdn"]="$address"
            done < "$lf"
          done

          # --- Load previously synced records ---
          declare -A OLD_RECORDS=()
          if [[ -f "$TRACKING_FILE" ]]; then
            while IFS='=' read -r name addr; do
              [[ -z "$name" ]] && continue
              # Migrate legacy bare-hostname tracking entries if present
              if [[ "$name" != *"." ]]; then
                name="''${name}.''${DOMAIN}."
              fi
              OLD_RECORDS["$name"]="$addr"
            done < "$TRACKING_FILE"
          fi

          # --- Add new / update changed records ---
          # Always call local_data for every lease (idempotent) — self-heals after
          # Unbound restarts even if the tracking file wasn't properly cleared.
          if [[ ''${#CURRENT_LEASES[@]} -gt 0 ]]; then
            for fqdn in "''${!CURRENT_LEASES[@]}"; do
              addr="''${CURRENT_LEASES[$fqdn]}"

              # Remove stale entry if IP changed
              if [[ -n "''${OLD_RECORDS[$fqdn]:-}" && "''${OLD_RECORDS[$fqdn]}" != "$addr" ]]; then
                "$UNBOUND" local_data_remove "$fqdn" 2>/dev/null || true
                echo "[ddns] $fqdn -> $addr (updated)"
              elif [[ -z "''${OLD_RECORDS[$fqdn]:-}" ]]; then
                echo "[ddns] $fqdn -> $addr"
              fi

              # Ensure record exists (idempotent — handles stale tracking file)
              if ! "$UNBOUND" local_data "$fqdn IN A $addr" >/dev/null 2>&1; then
                echo "[ddns] WARN: failed to add $fqdn -> $addr" >&2
              fi

              # Mark as processed
              unset "OLD_RECORDS[$fqdn]" 2>/dev/null || true
            done
          fi

          # --- Remove records for expired/released leases ---
          if [[ ''${#OLD_RECORDS[@]} -gt 0 ]]; then
            for fqdn in "''${!OLD_RECORDS[@]}"; do
              base_host="''${fqdn%%.*}"
              if [[ -n "''${PROTECTED_HOSTS[$base_host]:-}" && "$fqdn" == "''${base_host}.''${DOMAIN}." ]]; then
                # Never remove static local-data records migrated from an older tracking file
                continue
              fi
              "$UNBOUND" local_data_remove "$fqdn" 2>/dev/null || true
              echo "[ddns] removed $fqdn"
            done
          fi

          # --- Persist current state (atomic write) ---
          TMPFILE="''${TRACKING_FILE}.tmp"
          rm -f "$TMPFILE"
          : > "$TMPFILE"
          if [[ ''${#CURRENT_LEASES[@]} -gt 0 ]]; then
            for fqdn in "''${!CURRENT_LEASES[@]}"; do
              echo "''${fqdn}=''${CURRENT_LEASES[$fqdn]}" >> "$TMPFILE"
            done
          fi
          mv "$TMPFILE" "$TRACKING_FILE"

          echo "[ddns] synced ''${#CURRENT_LEASES[@]} lease(s)"
        '';
      };
    in
    {
      options.my.router.dns.ddns = {
        enable = lib.mkEnableOption "dynamic DNS updates from DHCP leases to Unbound";
        isolatedSegmentMode = lib.mkOption {
          type = lib.types.enum [
            "subdomain"
            "exclude"
          ];
          default = "subdomain";
          description = ''
            How DHCP leases from isolated VLAN segments (`isolation != "none"`) are registered in DNS:
            - `subdomain`: register only under `<hostname>.<segment>.<domain>` (e.g. `device.iot.home.arpa`)
            - `exclude`: do not register dynamic DNS records for isolated VLAN clients
          '';
        };
        extraBlockedHostnames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional hostnames blocked from dynamic DHCP DNS registration.";
        };
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

          systemd = {
            # Sync service — runs the script once per invocation
            services = {
              kea-unbound-sync = {
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

                  # Sandboxing: script parses attacker-influenced DHCP hostnames.
                  # Runs as unbound (owns unbound_control.key) with read-only DAC
                  # bypass so it can read Kea's DynamicUser /var/lib/private/kea CSV.
                  User = config.services.unbound.user;
                  Group = config.services.unbound.group;
                  AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
                  CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  PrivateTmp = true;
                  PrivateDevices = true;
                  ProtectHostname = true;
                  ProtectClock = true;
                  ProtectKernelTunables = true;
                  ProtectKernelModules = true;
                  ProtectKernelLogs = true;
                  ProtectControlGroups = true;
                  RestrictAddressFamilies = [
                    "AF_UNIX"
                    "AF_INET"
                    "AF_INET6"
                  ];
                  RestrictNamespaces = true;
                  RestrictRealtime = true;
                  RestrictSUIDSGID = true;
                  LockPersonality = true;
                  MemoryDenyWriteExecute = true;
                  SystemCallArchitectures = "native";
                  UMask = "0077";
                  NoNewPrivileges = true;
                };
              };

              # Ensure the safety-net timer starts whenever Unbound does.
              # partOf propagates stop but NOT start — without this, a manual
              # stop→start (or NixOS rebuild) leaves the timer dead.
              unbound = {
                wants = [ "kea-unbound-sync.timer" ];

                serviceConfig = {
                  # Clear tracking file when Unbound stops/restarts — dynamic records are
                  # lost on restart, so the next sync must re-add everything.
                  # '+' runs with full privileges (file is root-owned, Unbound runs as unbound user)
                  ExecStopPost = "+-${pkgs.coreutils}/bin/rm -f ${trackingFile}";

                  # Re-sync immediately after Unbound starts — triggers the sync service
                  # asynchronously (--no-block) so it doesn't block Unbound startup.
                  # '+' runs with root privileges (Unbound service runs as unbound user).
                  ExecStartPost = "+-${pkgs.systemd}/bin/systemctl start --no-block kea-unbound-sync.service";
                };
              };
            };

            # Path unit — triggers sync when Kea writes the lease file
            paths.kea-unbound-sync = {
              description = "Watch Kea lease file for changes";
              wantedBy = [ "multi-user.target" ];
              pathConfig = {
                PathModified = leaseFile;
                Unit = "kea-unbound-sync.service";
              };
            };

            # Timer — periodic fallback (catches missed inotify events)
            # partOf: when Unbound restarts (losing dynamic records), this timer
            # also restarts and fires immediately (OnBootSec triggers from activation)
            timers.kea-unbound-sync = {
              description = "Periodic Kea→Unbound lease sync";
              wantedBy = [ "timers.target" ];
              partOf = [ "unbound.service" ];
              timerConfig = {
                OnBootSec = "30s";
                OnUnitActiveSec = "5min";
              };
            };
          };
        })
      ];
    };
}
