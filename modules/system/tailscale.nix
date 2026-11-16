# Cross-platform Tailscale mesh VPN client connected to self-hosted Headscale.
#
# tailscaled never blocks boot or activation. Hosts enroll with a sops-held
# pre-auth key (`my.tailscale.authKeySecret`) or interactively with `tailscale-headscale-up`.
_: {
  flake.modules =
    let
      mkTailscaleOptions =
        {
          config,
          lib,
          pkgs,
        }:
        {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Tailscale mesh VPN client connected to self-hosted Headscale.";
          };

          loginServer = lib.mkOption {
            type = lib.types.str;
            default = "https://hs.${lib.my.homelab.publicDomain}:9443";
            defaultText = lib.literalExpression ''"https://hs.''${lib.my.homelab.publicDomain}:9443"'';
            description = "Self-hosted Headscale coordination server URL.";
          };

          magicDnsSuffix = lib.mkOption {
            type = lib.types.str;
            default = "pp-ts";
            description = "Tailnet MagicDNS search domain suffix.";
          };

          authKeySecret = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional sops secret name containing a Headscale pre-auth key for unattended enrollment.";
          };

          acceptDns = lib.mkOption {
            type = lib.types.bool;
            default =
              !(config.my.router.enable or false)
              && (
                pkgs.stdenv.hostPlatform.isDarwin
                || ((config.my.desktop.enable or false) && (config.services.resolved.enable or false))
              );
            defaultText = lib.literalExpression "!(config.my.router.enable or false) && (pkgs.stdenv.hostPlatform.isDarwin || ((config.my.desktop.enable or false) && (config.services.resolved.enable or false)))";
            description = "Accept Headscale split MagicDNS (`100.100.100.100`) on roaming admin workstations (`pp-ml1`, which holds `tag:admin` -> `*:*`); disabled on router, WSL, and always-on LAN servers (`pp-nas1`, `pp-rpi1`, which resolve `*.pp-ts` via the router's Unbound forward zone without injecting `tailscale0` per-link search domains into `systemd-resolved`).";
          };

          expectedIpv4 = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "100.64.0.1";
            description = "Expected Tailscale IPv4 address. When set, tailscale-headscale-up and a periodic systemd check fail loudly if the enrolled node receives a different IPv4.";
          };

          expectedIpv6 = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "fd7a:115c:a1e0::1";
            description = "Expected Tailscale IPv6 address. When set, tailscale-headscale-up and a periodic systemd check fail loudly if the enrolled node receives a different IPv6.";
          };

          disableTaildrop = lib.mkOption {
            type = lib.types.bool;
            default = !(config.my.desktop.enable or true);
            defaultText = lib.literalExpression "!(config.my.desktop.enable or true)";
            description = "Disable Taildrop file receive (enabled on desktops, disabled on headless servers).";
          };

          extraUpFlags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Additional flags passed to `tailscale up`.";
          };

          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = !(config.my.router.enable or false);
            defaultText = lib.literalExpression "!(config.my.router.enable or false)";
            description = "Open Tailscale UDP port in standard NixOS firewall (disabled on router which uses custom nftables).";
          };
        };

      mkVerifyIpsSnippet =
        {
          pkgs,
          lib,
          tailscalePkg,
          cfg,
          skipWhenNotRunning ? false,
        }:
        let
          jq = "${pkgs.jq}/bin/jq";
          tailscale = "${tailscalePkg}/bin/tailscale";
          expectedDesc = lib.concatStringsSep ", " (
            lib.optional (cfg.expectedIpv4 != null) cfg.expectedIpv4
            ++ lib.optional (cfg.expectedIpv6 != null) cfg.expectedIpv6
          );
        in
        lib.optionalString (cfg.expectedIpv4 != null || cfg.expectedIpv6 != null) ''
          status_json="$(${tailscale} status --json)"
          ${lib.optionalString skipWhenNotRunning ''
            state="$(${jq} -r '.BackendState // "Unknown"' <<<"$status_json")"
            if [ "$state" != "Running" ]; then
              echo "tailscale-ip-verify: BackendState=''${state} (not yet enrolled); skipping IP check."
              exit 0
            fi
          ''}
          actual_ips="$(${jq} -r '(.Self.TailscaleIPs // []) | join(", ")' <<<"$status_json")"
          ip_mismatch=0
          ${lib.optionalString (cfg.expectedIpv4 != null) ''
            if ! ${jq} -e --arg ip ${lib.escapeShellArg cfg.expectedIpv4} '((.Self.TailscaleIPs // []) | index($ip)) != null' <<<"$status_json" >/dev/null; then
              ip_mismatch=1
            fi
          ''}
          ${lib.optionalString (cfg.expectedIpv6 != null) ''
            if ! ${jq} -e --arg ip ${lib.escapeShellArg cfg.expectedIpv6} '((.Self.TailscaleIPs // []) | index($ip)) != null' <<<"$status_json" >/dev/null; then
              ip_mismatch=1
            fi
          ''}
          if [ "$ip_mismatch" -ne 0 ]; then
            echo "ERROR: Tailscale IP mismatch: expected [${expectedDesc}], got [''${actual_ips:-none}]" >&2
            exit 1
          fi
        '';

      mkUpHelper =
        {
          pkgs,
          lib,
          tailscalePkg,
          cfg,
        }:
        let
          hasExpectedIps = cfg.expectedIpv4 != null || cfg.expectedIpv6 != null;
        in
        pkgs.writeShellScriptBin "tailscale-headscale-up" (
          if hasExpectedIps then
            ''
              set -euo pipefail
              ${tailscalePkg}/bin/tailscale up \
                --login-server=${lib.escapeShellArg cfg.loginServer} \
                --accept-dns=${lib.boolToString cfg.acceptDns} \
                ${lib.escapeShellArgs cfg.extraUpFlags} \
                "$@"
              ${mkVerifyIpsSnippet {
                inherit
                  pkgs
                  lib
                  tailscalePkg
                  cfg
                  ;
              }}
            ''
          else
            ''
              exec ${tailscalePkg}/bin/tailscale up \
                --login-server=${lib.escapeShellArg cfg.loginServer} \
                --accept-dns=${lib.boolToString cfg.acceptDns} \
                ${lib.escapeShellArgs cfg.extraUpFlags} \
                "$@"
            ''
        );
    in
    {
      nixos.tailscale =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.my.tailscale;
          tailscalePkg = config.services.tailscale.package;
          upFlags = [
            "--login-server=${cfg.loginServer}"
            "--accept-dns=${lib.boolToString cfg.acceptDns}"
          ]
          ++ cfg.extraUpFlags;
        in
        {
          options.my.tailscale = mkTailscaleOptions { inherit config lib pkgs; };

          config = lib.mkIf cfg.enable (
            lib.mkMerge [
              {
                services.tailscale = {
                  enable = true;
                  inherit (cfg) openFirewall disableTaildrop;
                  disableUpstreamLogging = true;
                  authKeyFile =
                    if cfg.authKeySecret != null then config.sops.secrets.${cfg.authKeySecret}.path else null;
                  extraUpFlags = upFlags;
                };

                # Never let an unauthenticated or offline tailnet interface stall boot
                systemd.network.wait-online.ignoredInterfaces = [ config.services.tailscale.interfaceName ];

                environment.systemPackages = [
                  (mkUpHelper {
                    inherit
                      pkgs
                      lib
                      tailscalePkg
                      cfg
                      ;
                  })
                ];
              }
              (lib.mkIf (cfg.authKeySecret != null) {
                sops.secrets = lib.optionalAttrs (cfg.authKeySecret != null) {
                  ${cfg.authKeySecret} = {
                    mode = "0400";
                  };
                };
              })
              (lib.mkIf (cfg.expectedIpv4 != null || cfg.expectedIpv6 != null) {
                systemd = {
                  services.tailscale-ip-verify = {
                    description = "Verify enrolled Tailscale node IP addresses match expected configuration";
                    after = [
                      "tailscaled.service"
                      "tailscaled-autoconnect.service"
                    ];
                    wants = [ "tailscaled.service" ];
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      Type = "oneshot";
                    };
                    script = mkVerifyIpsSnippet {
                      inherit
                        pkgs
                        lib
                        tailscalePkg
                        cfg
                        ;
                      skipWhenNotRunning = true;
                    };
                  };

                  timers.tailscale-ip-verify = {
                    description = "Periodic Tailscale IP verification timer";
                    wantedBy = [ "timers.target" ];
                    timerConfig = {
                      OnBootSec = "1m";
                      OnUnitActiveSec = "5m";
                    };
                  };
                };
              })
            ]
          );
        };

      darwin.tailscale =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.my.tailscale;
          tailscalePkg = config.services.tailscale.package;
          upFlags = [
            "--login-server=${cfg.loginServer}"
            "--accept-dns=${lib.boolToString cfg.acceptDns}"
          ]
          ++ cfg.extraUpFlags;
        in
        {
          options.my.tailscale = mkTailscaleOptions { inherit config lib pkgs; };

          config = lib.mkIf cfg.enable (
            lib.mkMerge [
              {
                services.tailscale = {
                  enable = true;
                  overrideLocalDns = false;
                };

                launchd.daemons.tailscaled.serviceConfig = {
                  # nix-darwin only sets RunAtLoad, so a crashed tailscaled stays down until reboot.
                  KeepAlive = true;
                  EnvironmentVariables = {
                    TS_NO_LOGS_NO_SUPPORT = "true";
                  }
                  // lib.optionalAttrs cfg.disableTaildrop {
                    TS_DISABLE_TAILDROP = "true";
                  };
                };

                # nix-darwin's services.tailscale lacks extraUpFlags; provide a helper
                # CLI for interactive Headscale login without blocking system activation.
                environment.systemPackages = [
                  (mkUpHelper {
                    inherit
                      pkgs
                      lib
                      tailscalePkg
                      cfg
                      ;
                  })
                ];
              }
              (lib.mkIf (cfg.authKeySecret != null) {
                sops.secrets = lib.optionalAttrs (cfg.authKeySecret != null) {
                  ${cfg.authKeySecret} = {
                    mode = "0400";
                  };
                };

                launchd.daemons.tailscaled-autoconnect = {
                  serviceConfig = {
                    Label = "com.tailscale.tailscaled-autoconnect";
                    RunAtLoad = true;
                    ProgramArguments = [
                      (lib.getExe (
                        pkgs.writeShellApplication {
                          name = "tailscaled-autoconnect";
                          runtimeInputs = [
                            tailscalePkg
                            pkgs.jq
                            pkgs.coreutils
                          ];
                          text = ''
                            keyFile=${
                              lib.escapeShellArg (
                                if cfg.authKeySecret != null then config.sops.secrets.${cfg.authKeySecret}.path else ""
                              )
                            }
                            for _ in $(seq 1 30); do
                              if state=$(tailscale status --json --peers=false 2>/dev/null | jq -r '.BackendState'); then
                                case "$state" in
                                  NeedsLogin|NeedsMachineAuth|Stopped)
                                    if [ -r "$keyFile" ]; then
                                      tailscale up --auth-key="file:$keyFile" ${lib.escapeShellArgs upFlags}
                                    fi
                                    ;;
                                  Running)
                                    tailscale set --accept-dns=${lib.boolToString cfg.acceptDns} || true
                                    exit 0
                                    ;;
                                esac
                              fi
                              sleep 1
                            done
                          '';
                        }
                      ))
                    ];
                  };
                };
              })
            ]
          );
        };
    };
}
