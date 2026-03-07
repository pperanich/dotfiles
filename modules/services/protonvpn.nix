# ProtonVPN WireGuard tunnel — host mode (wg-quick) or namespace mode (split tunneling)
#
# Requires a WireGuard config from the ProtonVPN portal:
#   Settings → WireGuard → Create certificate/configuration
#
# During `clan vars generate <hostname>`, you'll be prompted for
# the private key from the generated config. All other values
# (server IP, public key, local IP) are set as module options.
#
# Does NOT conflict with the pp-wg mesh (which uses networking.wireguard.interfaces
# with systemd-networkd; host mode uses wg-quick, namespace mode uses raw wg/ip
# in a separate network namespace).
#
# ## Host mode (default) — all traffic through VPN
#
#   my.protonvpn = {
#     enable = true;
#     endpoint.ip = "193.148.18.68";
#     endpoint.publicKey = "abc123...=";
#     interface.ip = "10.2.0.2/32";
#     killSwitch = "iptables";        # or "persistent" or "none"
#   };
#
# ## Namespace mode — only specified services use VPN
#
#   my.protonvpn = {
#     enable = true;
#     mode = "namespace";
#     endpoint.ip = "193.148.18.68";
#     endpoint.publicKey = "abc123...=";
#     interface.ip = "10.2.0.2/32";
#     namespace.confinedServices.transmission = {
#       serviceUnit = "transmission";
#       socketProxy = {
#         "0.0.0.0:9091" = "127.0.0.1:9091";
#       };
#     };
#   };
_: {
  flake.modules.nixos.protonvpn =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.protonvpn;
      useClanVars = cfg.interface.privateKeyFile == null;
      keyFile =
        if useClanVars then
          config.clan.core.vars.generators.protonvpn.files.private-key.path
        else
          cfg.interface.privateKeyFile;
      ifName = cfg.interface.name;
      nsName = cfg.namespace.name;

      # Unit name for the VPN tunnel (differs by mode)
      tunnelUnit =
        if cfg.mode == "host" then "wg-quick-${ifName}.service" else "protonvpn-tunnel.service";

      # Binaries (fully qualified)
      ip = "${pkgs.iproute2}/bin/ip";
      iptables = "${pkgs.iptables}/bin/iptables";
      ip6tables = "${pkgs.iptables}/bin/ip6tables";
      wg = "${pkgs.wireguard-tools}/bin/wg";
      curl = "${pkgs.curl}/bin/curl";
      dig = "${pkgs.dnsutils}/bin/dig";
      awk = "${pkgs.gawk}/bin/awk";

      # Shared peer config (host mode wg-quick only)
      peerConfig = {
        inherit (cfg.endpoint) publicKey;
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
        endpoint = "${cfg.endpoint.ip}:${toString cfg.endpoint.port}";
        persistentKeepalive = 25;
      };

      # --- Kill switch helpers (host mode, iptables variant) ---
      iptablesPostUp = ''
        FWMARK=$(${wg} show ${ifName} fwmark)
        if [ -z "$FWMARK" ] || [ "$FWMARK" = "off" ]; then
          echo "ERROR: fwmark not available on ${ifName}" >&2
          exit 1
        fi
        ${iptables} -I OUTPUT ! -o ${ifName} \
          -m mark ! --mark "$FWMARK" \
          -m addrtype ! --dst-type LOCAL \
          -j REJECT
        ${ip6tables} -I OUTPUT ! -o ${ifName} \
          -m mark ! --mark "$FWMARK" \
          -m addrtype ! --dst-type LOCAL \
          -j REJECT
      '';

      iptablesPreDown = ''
        FWMARK=$(${wg} show ${ifName} fwmark 2>/dev/null || echo "")
        if [ -n "$FWMARK" ] && [ "$FWMARK" != "off" ]; then
          ${iptables} -D OUTPUT ! -o ${ifName} \
            -m mark ! --mark "$FWMARK" \
            -m addrtype ! --dst-type LOCAL \
            -j REJECT || true
          ${ip6tables} -D OUTPUT ! -o ${ifName} \
            -m mark ! --mark "$FWMARK" \
            -m addrtype ! --dst-type LOCAL \
            -j REJECT || true
        fi
      '';

      # --- Persistent kill switch (iptables custom chain) ---
      chainName = "protonvpn-kill";

      persistentChainUp = ''
        # Create custom chain
        ${iptables} -N ${chainName} 2>/dev/null || ${iptables} -F ${chainName}
        ${ip6tables} -N ${chainName} 2>/dev/null || ${ip6tables} -F ${chainName}

        # Allow loopback
        ${iptables} -A ${chainName} -o lo -j ACCEPT
        ${ip6tables} -A ${chainName} -o lo -j ACCEPT

        # Allow VPN interface
        ${iptables} -A ${chainName} -o ${ifName} -j ACCEPT
        ${ip6tables} -A ${chainName} -o ${ifName} -j ACCEPT

        # Allow traffic to VPN endpoint (WireGuard handshake only)
        ${iptables} -A ${chainName} -d ${cfg.endpoint.ip}/32 -p udp --dport ${toString cfg.endpoint.port} -j ACCEPT

        # Allow RFC1918 IPv4 (LAN + pp-wg mesh)
        ${iptables} -A ${chainName} -d 10.0.0.0/8 -j ACCEPT
        ${iptables} -A ${chainName} -d 172.16.0.0/12 -j ACCEPT
        ${iptables} -A ${chainName} -d 192.168.0.0/16 -j ACCEPT

        # Allow ULA IPv6 (pp-wg mesh uses fdb4::/16 prefix)
        ${ip6tables} -A ${chainName} -d fc00::/7 -j ACCEPT

        # Allow link-local IPv6 (neighbor discovery)
        ${ip6tables} -A ${chainName} -d fe80::/10 -j ACCEPT

        # Reject everything else
        ${iptables} -A ${chainName} -j REJECT
        ${ip6tables} -A ${chainName} -j REJECT

        # Insert chain into OUTPUT
        ${iptables} -I OUTPUT -j ${chainName}
        ${ip6tables} -I OUTPUT -j ${chainName}
      '';

      persistentChainDown = ''
        ${iptables} -D OUTPUT -j ${chainName} 2>/dev/null || true
        ${ip6tables} -D OUTPUT -j ${chainName} 2>/dev/null || true
        ${iptables} -F ${chainName} 2>/dev/null || true
        ${ip6tables} -F ${chainName} 2>/dev/null || true
        ${iptables} -X ${chainName} 2>/dev/null || true
        ${ip6tables} -X ${chainName} 2>/dev/null || true
      '';

      # --- Namespace mode helpers ---
      svcNameOf = name: "protonvpn-proxy-${name}";

      mkConfinedService = name: svcCfg: {
        systemd.services = {
          # Override the original service to run inside the VPN namespace
          ${svcCfg.serviceUnit} = {
            bindsTo = [
              "protonvpn-netns.service"
              "protonvpn-tunnel.service"
            ];
            after = [
              "protonvpn-netns.service"
              "protonvpn-tunnel.service"
            ];
            serviceConfig = {
              NetworkNamespacePath = "/var/run/netns/${nsName}";
              BindReadOnlyPaths = [ "/etc/netns/${nsName}/resolv.conf:/etc/resolv.conf" ];
              InaccessiblePaths = [
                "-/run/nscd"
                "-/run/resolvconf"
              ];
            };
          };
        }
        // lib.mapAttrs' (
          hostBind: nsBind:
          let
            hostParts = lib.splitString ":" hostBind;
            hostAddr = builtins.elemAt hostParts 0;
            hostPort = builtins.elemAt hostParts 1;
            # Inner script runs socat inside the namespace to connect to the target
            innerScript = pkgs.writeShellScript "protonvpn-ns-connect-${name}-${hostPort}" ''
              exec ${pkgs.socat}/bin/socat STDIO "TCP:${nsBind}"
            '';
          in
          lib.nameValuePair (svcNameOf "${name}-${hostPort}") {
            description = "Socket proxy ${hostBind} -> ${nsBind} (${name} via ProtonVPN)";
            after = [ "${svcCfg.serviceUnit}.service" ];
            bindsTo = [ "${svcCfg.serviceUnit}.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = pkgs.writeShellScript "protonvpn-proxy-${name}-${hostPort}" ''
                exec ${pkgs.socat}/bin/socat \
                  "TCP-LISTEN:${hostPort},bind=${hostAddr},fork,reuseaddr" \
                  "EXEC:${ip} netns exec ${nsName} ${innerScript}"
              '';
              Restart = "on-failure";
              RestartSec = 5;
            };
          }
        ) svcCfg.socketProxy;
      };

      # --- Config blocks ---
      sharedConfig = {
        # Clan vars: prompt for private key during `clan vars generate`
        clan.core.vars.generators.protonvpn = lib.mkIf useClanVars {
          files.private-key = { };
          prompts.private-key = {
            description = "ProtonVPN WireGuard private key (Settings → WireGuard → Create config)";
            type = "hidden";
            persist = true;
          };
          script = "cp \"$prompts/private-key\" \"$out/private-key\"";
        };

        # Don't block boot waiting for the VPN interface
        systemd.network.wait-online.ignoredInterfaces = [ ifName ];
      };

      hostModeConfig = lib.mkIf (cfg.mode == "host") {
        # Prevent systemd-networkd from removing wg-quick routing rules.
        # wg-quick creates `ip rule` entries for policy routing. Without this,
        # systemd-networkd (used by the pp-wg mesh) may garbage-collect them.
        systemd.network.config.networkConfig.ManageForeignRoutingPolicyRules = false;

        networking.wg-quick.interfaces.${ifName} = {
          inherit (cfg) autostart;
          address = [ cfg.interface.ip ];
          privateKeyFile = keyFile;
          dns = lib.mkIf cfg.dns.enable cfg.dns.addresses;
          mtu = lib.mkIf (cfg.mtu != null) cfg.mtu;

          peers = [ peerConfig ];

          postUp = lib.mkIf (cfg.killSwitch == "iptables") iptablesPostUp;
          preDown = lib.mkIf (cfg.killSwitch == "iptables") iptablesPreDown;
        };

        # Persistent kill switch — survives VPN restarts
        systemd.services.protonvpn-killswitch = lib.mkIf (cfg.killSwitch == "persistent") {
          description = "ProtonVPN persistent kill switch (iptables chain)";
          wantedBy = [ "multi-user.target" ];
          before = [ "wg-quick-${ifName}.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "protonvpn-killswitch-up" persistentChainUp;
            ExecStop = pkgs.writeShellScript "protonvpn-killswitch-down" persistentChainDown;
          };
        };

        # When autostart is disabled, remove wg-quick from default target
        systemd.services."wg-quick-${ifName}" = lib.mkIf (!cfg.autostart) {
          wantedBy = lib.mkForce [ ];
        };
      };

      namespaceModeConfig = lib.mkIf (cfg.mode == "namespace") (
        lib.mkMerge (
          [
            {
              # Create the network namespace
              systemd.services.protonvpn-netns = {
                description = "ProtonVPN network namespace (${nsName})";
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = "${ip} netns add ${nsName}";
                  ExecStartPost = "${ip} -n ${nsName} link set lo up";
                  ExecStop = "${ip} netns del ${nsName}";
                };
              };

              # WireGuard tunnel — raw wg/ip, no wg-quick
              # wg-quick is unsuitable for namespace mode because:
              #  - it applies address/DNS/routes in the host namespace before postUp
              #  - its teardown can't find the interface after it's been moved
              #  - its DNS setting poisons the host resolver
              systemd.services.protonvpn-tunnel = {
                description = "ProtonVPN WireGuard tunnel (namespace)";
                after = [ "protonvpn-netns.service" ];
                bindsTo = [ "protonvpn-netns.service" ];
                wantedBy = lib.mkIf cfg.autostart [ "multi-user.target" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = pkgs.writeShellScript "protonvpn-tunnel-up" ''
                    set -euo pipefail

                    # Clean up stale interface from prior failed start
                    # (could be in host or namespace depending on where failure occurred)
                    ${ip} -n ${nsName} link del ${ifName} 2>/dev/null || true
                    ${ip} link del ${ifName} 2>/dev/null || true

                    # Create WireGuard interface and configure in host namespace
                    # (key is loaded into kernel memory, then file is no longer needed)
                    ${ip} link add ${ifName} type wireguard
                    ${wg} set ${ifName} \
                      private-key ${keyFile} \
                      peer ${cfg.endpoint.publicKey} \
                        endpoint ${cfg.endpoint.ip}:${toString cfg.endpoint.port} \
                        allowed-ips 0.0.0.0/0,::/0 \
                        persistent-keepalive 25

                    # Move interface into namespace
                    ${ip} link set ${ifName} netns ${nsName}

                    # Configure inside namespace
                    ${ip} -n ${nsName} addr add ${cfg.interface.ip} dev ${ifName}
                    ${lib.optionalString (
                      cfg.mtu != null
                    ) "${ip} -n ${nsName} link set ${ifName} mtu ${toString cfg.mtu}"}
                    ${ip} -n ${nsName} link set ${ifName} up
                    ${ip} -n ${nsName} route add default dev ${ifName}
                    ${ip} -n ${nsName} -6 route add default dev ${ifName} 2>/dev/null || true
                  '';
                  ExecStop = pkgs.writeShellScript "protonvpn-tunnel-down" ''
                    ${ip} -n ${nsName} link del ${ifName} 2>/dev/null || true
                  '';
                };
              };

              # DNS for the namespace — static resolv.conf
              environment.etc."netns/${nsName}/resolv.conf" = lib.mkIf cfg.dns.enable {
                text = (lib.concatMapStringsSep "\n" (addr: "nameserver ${addr}") cfg.dns.addresses) + "\n";
              };
            }
          ]
          ++ lib.mapAttrsToList mkConfinedService cfg.namespace.confinedServices
        )
      );

      # --- Verify services (on-demand, manual start only) ---
      verifyConfig = lib.mkIf cfg.verify.enable {
        systemd.services.protonvpn-verify = {
          description = "Verify ProtonVPN tunnel is working";
          after = [ tunnelUnit ];
          # No wantedBy — manual start only: systemctl start protonvpn-verify
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "protonvpn-verify" (
              if cfg.mode == "namespace" then
                ''
                  set -euo pipefail

                  echo "=== ProtonVPN Verify (namespace mode) ==="

                  echo "--- Tunnel interface ---"
                  ${ip} -n ${nsName} addr show ${ifName} 2>/dev/null \
                    || { echo "FAIL: interface ${ifName} not found in namespace ${nsName}"; exit 1; }

                  echo ""
                  echo "--- WireGuard handshake ---"
                  HANDSHAKE=$(${ip} netns exec ${nsName} ${wg} show ${ifName} latest-handshakes \
                    | ${awk} '{print $2}')
                  NOW=$(date +%s)
                  if [ -n "$HANDSHAKE" ] && [ "$HANDSHAKE" -gt 0 ]; then
                    AGE=$((NOW - HANDSHAKE))
                    echo "Last handshake: ''${AGE}s ago"
                    if [ "$AGE" -gt 180 ]; then
                      echo "WARN: handshake is stale (>3 min)"
                    fi
                  else
                    echo "WARN: no WireGuard handshake yet (tunnel may need traffic to initiate)"
                  fi

                  echo ""
                  echo "--- Public IP comparison ---"
                  # Resolve api.ipify.org from host (host has working DNS)
                  API_ADDR=$(${curl} -s4 --max-time 5 -o /dev/null -w '%{remote_ip}' https://api.ipify.org || echo "")
                  if [ -z "$API_ADDR" ]; then
                    echo "FAIL: could not resolve api.ipify.org from host"
                    exit 1
                  fi

                  HOST_IP=$(${curl} -s4 --max-time 10 https://api.ipify.org || echo "FAILED")
                  echo "Host IP:      $HOST_IP"

                  # Use --resolve to inject host-resolved IP into namespace curl
                  # (ip netns exec doesn't mount the namespace resolv.conf)
                  VPN_IP=$(${ip} netns exec ${nsName} ${curl} -s4 --max-time 10 \
                    --resolve "api.ipify.org:443:$API_ADDR" \
                    https://api.ipify.org || echo "FAILED")
                  echo "Namespace IP: $VPN_IP"

                  if [ "$VPN_IP" = "FAILED" ]; then
                    echo "FAIL: could not reach internet from namespace"
                    exit 1
                  elif [ "$HOST_IP" = "FAILED" ]; then
                    echo "WARN: could not check host IP for comparison"
                    echo "Namespace IP: $VPN_IP"
                  elif [ "$VPN_IP" != "$HOST_IP" ]; then
                    echo "PASS: namespace routes through VPN (IPs differ)"
                  else
                    echo "FAIL: namespace IP matches host IP — traffic may not be tunneled"
                    exit 1
                  fi

                  echo ""
                  echo "--- DNS (namespace -> VPN resolver) ---"
                  DNS_RESULT=$(${ip} netns exec ${nsName} ${dig} \
                    @${lib.head cfg.dns.addresses} +short +timeout=5 example.com A 2>/dev/null \
                    || echo "FAILED")
                  if [ "$DNS_RESULT" = "FAILED" ] || [ -z "$DNS_RESULT" ]; then
                    echo "WARN: DNS query to ${lib.head cfg.dns.addresses} failed from namespace"
                  else
                    echo "PASS: DNS resolves via VPN (example.com -> $DNS_RESULT)"
                  fi
                ''
              else
                ''
                  set -euo pipefail

                  echo "=== ProtonVPN Verify (host mode) ==="

                  echo "--- Interface ---"
                  ${wg} show ${ifName} 2>/dev/null \
                    || { echo "FAIL: WireGuard interface ${ifName} not found"; exit 1; }

                  echo ""
                  echo "--- Handshake ---"
                  HANDSHAKE=$(${wg} show ${ifName} latest-handshakes | ${awk} '{print $2}')
                  NOW=$(date +%s)
                  if [ -n "$HANDSHAKE" ] && [ "$HANDSHAKE" -gt 0 ]; then
                    AGE=$((NOW - HANDSHAKE))
                    echo "Last handshake: ''${AGE}s ago"
                    if [ "$AGE" -gt 180 ]; then
                      echo "WARN: handshake is stale (>3 min)"
                    fi
                  else
                    echo "FAIL: no WireGuard handshake recorded"
                    exit 1
                  fi

                  echo ""
                  echo "--- Public IP ---"
                  CURRENT_IP=$(${curl} -s4 --max-time 10 https://api.ipify.org || echo "FAILED")
                  if [ "$CURRENT_IP" = "FAILED" ]; then
                    echo "FAIL: could not reach internet"
                    exit 1
                  fi
                  echo "Public IP:    $CURRENT_IP"
                  echo "VPN endpoint: ${cfg.endpoint.ip}"

                  echo ""
                  echo "--- DNS ---"
                  DNS_RESULT=$(${dig} +short +timeout=5 example.com A 2>/dev/null || echo "FAILED")
                  if [ "$DNS_RESULT" = "FAILED" ] || [ -z "$DNS_RESULT" ]; then
                    echo "WARN: DNS resolution failed"
                  else
                    echo "PASS: DNS resolves (example.com -> $DNS_RESULT)"
                  fi

                  echo ""
                  echo "PASS: tunnel is active"
                ''
            );
          };
        };

        # Leak test — temporarily stops the tunnel to prove namespace isolation
        # Only available in namespace mode (host mode uses kill switch instead)
        systemd.services.protonvpn-verify-leak = lib.mkIf (cfg.mode == "namespace") {
          description = "Verify ProtonVPN namespace is leak-proof (temporarily stops tunnel!)";
          # No wantedBy — manual start only: systemctl start protonvpn-verify-leak
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "protonvpn-verify-leak" ''
              set -euo pipefail

              echo "=== ProtonVPN Leak Test (namespace mode) ==="
              echo "WARNING: This temporarily stops the VPN tunnel."
              echo ""

              # --- Pre-check: resolve API address while host DNS works ---
              API_ADDR=$(${curl} -s4 --max-time 5 -o /dev/null -w '%{remote_ip}' https://api.ipify.org || echo "")
              if [ -z "$API_ADDR" ]; then
                echo "FAIL: could not resolve api.ipify.org from host (needed for test)"
                exit 1
              fi

              # --- Pre-check: confirm tunnel is working ---
              echo "--- Step 1: Confirm tunnel is active ---"
              PRE_IP=$(${ip} netns exec ${nsName} ${curl} -s4 --max-time 10 \
                --resolve "api.ipify.org:443:$API_ADDR" \
                https://api.ipify.org || echo "FAILED")
              if [ "$PRE_IP" = "FAILED" ]; then
                echo "FAIL: namespace has no internet — tunnel may not be running"
                echo "Start the tunnel first: systemctl start protonvpn-tunnel"
                exit 1
              fi
              echo "Namespace IP before disconnect: $PRE_IP"

              # --- Stop tunnel ---
              echo ""
              echo "--- Step 2: Stopping tunnel ---"
              systemctl stop protonvpn-tunnel.service
              sleep 1

              # --- Verify namespace is isolated ---
              echo ""
              echo "--- Step 3: Checking namespace isolation ---"

              # Check 1: No non-loopback interfaces
              IFACES=$(${ip} -n ${nsName} -o link show 2>/dev/null | grep -cv '^\s*[0-9]*: lo:' || echo "0")
              if [ "$IFACES" -eq 0 ]; then
                echo "PASS: no non-loopback interfaces in namespace"
              else
                echo "FAIL: found $IFACES non-loopback interface(s) in namespace after tunnel stop"
                ${ip} -n ${nsName} -o link show 2>/dev/null || true
                systemctl start protonvpn-tunnel.service
                exit 1
              fi

              # Check 2: No default route
              DEFAULT_ROUTES=$(${ip} -n ${nsName} route show default 2>/dev/null | wc -l)
              if [ "$DEFAULT_ROUTES" -eq 0 ]; then
                echo "PASS: no default route in namespace"
              else
                echo "FAIL: default route still exists in namespace after tunnel stop"
                ${ip} -n ${nsName} route show 2>/dev/null || true
                systemctl start protonvpn-tunnel.service
                exit 1
              fi

              # Check 3: Cannot reach internet
              LEAK_IP=$(${ip} netns exec ${nsName} ${curl} -s4 --max-time 5 \
                --resolve "api.ipify.org:443:$API_ADDR" \
                https://api.ipify.org 2>/dev/null || echo "BLOCKED")
              if [ "$LEAK_IP" = "BLOCKED" ]; then
                echo "PASS: namespace cannot reach internet without VPN"
              else
                echo "FAIL: LEAK DETECTED — namespace reached internet without VPN!"
                echo "Leaked IP: $LEAK_IP"
                systemctl start protonvpn-tunnel.service
                exit 1
              fi

              # --- Restart tunnel ---
              echo ""
              echo "--- Step 4: Restarting tunnel ---"
              systemctl start protonvpn-tunnel.service
              sleep 2

              # --- Post-check: confirm connectivity restored ---
              echo ""
              echo "--- Step 5: Confirming connectivity restored ---"
              POST_IP=$(${ip} netns exec ${nsName} ${curl} -s4 --max-time 10 \
                --resolve "api.ipify.org:443:$API_ADDR" \
                https://api.ipify.org || echo "FAILED")
              if [ "$POST_IP" = "FAILED" ]; then
                echo "WARN: namespace connectivity not restored yet (tunnel may need more time)"
                echo "Check: systemctl status protonvpn-tunnel"
              else
                echo "Namespace IP after reconnect: $POST_IP"
                echo "PASS: connectivity restored"
              fi

              echo ""
              echo "=== RESULT: Namespace is leak-proof ==="
              echo "When the VPN disconnects, confined services have zero network access."
            '';
          };
        };
      };
    in
    {
      options.my.protonvpn = {
        enable = lib.mkEnableOption "ProtonVPN WireGuard tunnel";

        mode = lib.mkOption {
          type = lib.types.enum [
            "host"
            "namespace"
          ];
          default = "host";
          description = ''
            Operating mode for the VPN tunnel.

            - "host": All host traffic routes through the VPN (wg-quick with default route).
              Suitable when the entire machine should be behind ProtonVPN.
            - "namespace": The VPN runs inside a network namespace using raw wg/ip commands.
              Only services explicitly confined to the namespace use the VPN. Host traffic
              is unaffected. See docs/wireguard-split-tunneling.md for details.
          '';
        };

        autostart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Automatically start the ProtonVPN tunnel at boot.";
        };

        mtu = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          example = 1420;
          description = ''
            MTU for the WireGuard interface. When null, the kernel default is used
            (typically 1420 for WireGuard). Lower values may help on networks with
            smaller MTU (e.g., PPPoE, some mobile carriers).
          '';
        };

        interface = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "protonvpn";
            description = "Name of the WireGuard network interface (max 15 characters).";
          };

          ip = lib.mkOption {
            type = lib.types.str;
            default = "10.2.0.2/32";
            example = "10.2.0.2/32";
            description = "Local tunnel IP address (from your ProtonVPN WireGuard config).";
          };

          privateKeyFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            example = "/run/secrets/protonvpn-key";
            description = ''
              Path to the WireGuard private key file. When null (default),
              the key is managed via clan vars — you'll be prompted during
              `clan vars generate <hostname>`.

              Set this to use sops-nix or another secret manager instead.
            '';
          };
        };

        endpoint = {
          ip = lib.mkOption {
            type = lib.types.str;
            example = "193.148.18.68";
            description = "IP address of the ProtonVPN server (from your WireGuard config).";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 51820;
            description = "Port of the ProtonVPN server endpoint.";
          };

          publicKey = lib.mkOption {
            type = lib.types.str;
            example = "abc123...=";
            description = "WireGuard public key of the ProtonVPN server (from your config).";
          };
        };

        dns = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Use ProtonVPN's DNS servers (prevents DNS leaks).";
          };

          addresses = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "10.2.0.1" ];
            description = "DNS server addresses provided by ProtonVPN.";
          };
        };

        killSwitch = lib.mkOption {
          type = lib.types.enum [
            "none"
            "iptables"
            "persistent"
          ];
          default = "none";
          description = ''
            Kill switch mode for host-mode VPN.

            - "none": No kill switch. Traffic routes normally if VPN drops.
            - "iptables": Inline iptables rules added in postUp, removed in preDown.
              If the VPN drops, non-VPN traffic is rejected. Stopping the service
              restores normal routing.
            - "persistent": A dedicated systemd service installs an iptables chain
              that survives VPN restarts. Traffic is blocked even between VPN stop
              and start. LAN (RFC1918), ULA IPv6 (pp-wg mesh), loopback, and the
              VPN endpoint are always allowed.

            Only applies in host mode. For namespace mode, services are inherently
            isolated — they can only reach the network through the VPN.
          '';
        };

        verify = {
          enable = lib.mkEnableOption "on-demand VPN verification service (systemctl start protonvpn-verify)";
        };

        namespace = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "protonvpn";
            description = "Name of the network namespace (used for /var/run/netns/<name>).";
          };

          confinedServices = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  serviceUnit = lib.mkOption {
                    type = lib.types.str;
                    description = ''
                      Name of the systemd service to confine (without .service suffix).
                      This service will be moved into the VPN namespace.
                    '';
                  };

                  socketProxy = lib.mkOption {
                    type = lib.types.attrsOf lib.types.str;
                    default = { };
                    example = {
                      "0.0.0.0:9091" = "127.0.0.1:9091";
                    };
                    description = ''
                      Socket proxies to expose namespace ports on the host.
                      Keys are host bind addresses (addr:port), values are namespace
                      target addresses (addr:port). Uses socat to bridge across the
                      network namespace boundary (TCP only).
                    '';
                  };
                };
              }
            );
            default = { };
            description = ''
              Services to confine inside the ProtonVPN network namespace.
              Each service will have its NetworkNamespacePath set and will
              only be able to reach the network through the VPN tunnel.
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          # --- Assertions ---
          {
            assertions = [
              {
                assertion = cfg.mode == "host" || cfg.killSwitch == "none";
                message = ''
                  my.protonvpn: killSwitch is only supported in host mode.
                  In namespace mode, services are inherently isolated.
                '';
              }
              {
                assertion = cfg.mode == "namespace" -> cfg.dns.enable;
                message = ''
                  my.protonvpn: DNS must be enabled in namespace mode.
                  The namespace has no DNS by default; disable dns.enable only in host mode.
                '';
              }
              {
                assertion = builtins.stringLength ifName <= 15;
                message = ''
                  my.protonvpn: interface name '${ifName}' exceeds the Linux 15-character limit.
                '';
              }
              {
                assertion =
                  let
                    units = lib.mapAttrsToList (_: s: s.serviceUnit) cfg.namespace.confinedServices;
                  in
                  units == lib.unique units;
                message = ''
                  my.protonvpn: each confinedService must reference a unique serviceUnit.
                '';
              }
            ];
          }
          sharedConfig
          hostModeConfig
          namespaceModeConfig
          verifyConfig
        ]
      );
    };
}
