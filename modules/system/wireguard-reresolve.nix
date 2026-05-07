_: {
  # Periodic WireGuard endpoint re-resolution.
  #
  # systemd-networkd resolves WireGuardPeer.Endpoint hostnames once at unit-start
  # and never again, so when the upstream WAN IP rotates, the cached IP goes
  # stale and the tunnel silently dies until manual reconfigure. This module
  # adds a small timer that detects stale handshakes and re-applies the wg
  # interface configuration so the hostname is re-resolved.
  flake.modules.nixos.wireguardReresolve =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.wireguardReresolve;

      reresolveScript = pkgs.writeShellApplication {
        name = "wg-reresolve";
        runtimeInputs = [
          config.systemd.package
          pkgs.wireguard-tools
          pkgs.coreutils
        ];
        # SC2043: cfg.interfaces may legitimately have one entry.
        excludeShellChecks = [ "SC2043" ];
        text = ''
          set -u
          now=$(date +%s)
          for iface in ${lib.concatStringsSep " " cfg.interfaces}; do
            if ! wg show "$iface" >/dev/null 2>&1; then
              echo "wg-reresolve: $iface not present, skipping"
              continue
            fi
            stale=0
            while read -r _pub hs; do
              if [ "$hs" -eq 0 ]; then
                stale=1
                break
              fi
              age=$((now - hs))
              if [ "$age" -gt ${toString cfg.staleThreshold} ]; then
                stale=1
                break
              fi
            done < <(wg show "$iface" latest-handshakes)
            if [ "$stale" -eq 1 ]; then
              echo "wg-reresolve: $iface handshake stale (>${toString cfg.staleThreshold}s), reconfiguring"
              networkctl reconfigure "$iface" || true
            fi
          done
        '';
      };
    in
    {
      options.my.wireguardReresolve = {
        interfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "pp-wg" ];
          description = "WireGuard interfaces to monitor for stale endpoints";
        };
        interval = lib.mkOption {
          type = lib.types.str;
          default = "1min";
          example = "5min";
          description = "Timer interval (systemd time-span format)";
        };
        staleThreshold = lib.mkOption {
          type = lib.types.int;
          default = 75;
          description = ''
            Reconfigure interface when any peer's latest-handshake age exceeds
            this many seconds. Default 75s = 3× default PersistentKeepalive.
          '';
        };
      };

      config = {
        systemd.services.wireguard-reresolve = {
          description = "Re-resolve stale WireGuard peer endpoints";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe reresolveScript;
          };
        };
        systemd.timers.wireguard-reresolve = {
          description = "Periodic WireGuard endpoint re-resolution check";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = cfg.interval;
            OnUnitActiveSec = cfg.interval;
            AccuracySec = "10s";
          };
        };
      };
    };
}
