_: {
  flake.modules.nixos.routerHostapd =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.features.router;
      hostapdCfg = cfg.hostapd;
      enabled = cfg.enable && hostapdCfg.enable;

      # Radio submodule type (each radio = one hostapd instance)
      radioSubmodule = lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable this radio";
            };

            interface = lib.mkOption {
              type = lib.types.str;
              example = "wlan0";
              description = "Physical wireless interface for this radio";
            };

            band = lib.mkOption {
              type = lib.types.enum [
                "2.4GHz"
                "5GHz"
                "6GHz"
              ];
              example = "5GHz";
              description = "Frequency band for this radio";
            };

            ssid = lib.mkOption {
              type = lib.types.str;
              example = "MyNetwork-5G";
              description = "Wireless network name (SSID)";
            };

            wpaPassphrase = lib.mkOption {
              type = lib.types.str;
              description = "WPA2/WPA3 passphrase (8-63 characters)";
            };

            wpaKeyMgmt = lib.mkOption {
              type = lib.types.str;
              default = "WPA-PSK";
              example = "SAE WPA-PSK";
              description = "Key management. 'SAE' for WPA3, 'WPA-PSK' for WPA2, 'SAE WPA-PSK' for transition mode.";
            };

            bssid = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "02:00:00:00:00:01";
              description = "Explicit BSSID for this radio. Required for 802.11r if not using bridge.";
            };

            bridge = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "br-lan";
              description = "Bridge interface to add this radio to";
            };

            channel = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Wireless channel. 0 = ACS (automatic channel selection) if supported.";
            };

            driver = lib.mkOption {
              type = lib.types.str;
              default = "nl80211";
              description = "Hostapd driver";
            };

            ieee80211n = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable 802.11n (Wi-Fi 4)";
            };

            ieee80211ac = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable 802.11ac (Wi-Fi 5). Only for 5GHz.";
            };

            ieee80211ax = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable 802.11ax (Wi-Fi 6)";
            };

            htCapab = lib.mkOption {
              type = lib.types.str;
              default = "";
              example = "[HT40+][SHORT-GI-40][DSSS_CCK-40]";
              description = "HT capabilities for 802.11n. Leave empty for auto-detection on supported drivers.";
            };

            vhtCapab = lib.mkOption {
              type = lib.types.str;
              default = "";
              example = "[MAX-MPDU-11454][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][SU-BEAMFORMEE]";
              description = "VHT capabilities for 802.11ac";
            };

            vhtOperChwidth = lib.mkOption {
              type = lib.types.int;
              default = 1;
              description = "VHT channel width (0=20/40MHz, 1=80MHz, 2=160MHz, 3=80+80MHz)";
            };

            vhtOperCentrFreqSeg0Idx = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              example = 42;
              description = "VHT center frequency segment 0. Required for 80MHz+ channels.";
            };

            extraSettings = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.oneOf [
                  lib.types.str
                  lib.types.int
                  lib.types.bool
                ]
              );
              default = { };
              description = "Additional hostapd settings for this radio";
            };

            additionalBSS = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    interface = lib.mkOption {
                      type = lib.types.str;
                      example = "wlan0_guest";
                      description = "Virtual interface name for this BSS";
                    };
                    ssid = lib.mkOption {
                      type = lib.types.str;
                      description = "SSID for this BSS";
                    };
                    wpaPassphrase = lib.mkOption {
                      type = lib.types.str;
                      description = "WPA passphrase for this BSS";
                    };
                    wpaKeyMgmt = lib.mkOption {
                      type = lib.types.str;
                      default = "WPA-PSK";
                      description = "Key management for this BSS";
                    };
                    bridge = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Bridge for this BSS";
                    };
                    extraSettings = lib.mkOption {
                      type = lib.types.attrsOf (
                        lib.types.oneOf [
                          lib.types.str
                          lib.types.int
                          lib.types.bool
                        ]
                      );
                      default = { };
                      description = "Additional settings for this BSS";
                    };
                  };
                }
              );
              default = [ ];
              description = "Additional BSSes (virtual interfaces) on this radio";
            };
          };
        }
      );

      # Helper: convert band to hw_mode
      bandToHwMode =
        band:
        {
          "2.4GHz" = "g";
          "5GHz" = "a";
          "6GHz" = "a";
        }
        .${band};

      # Helper: generate hostapd config lines
      mkHostapdLines =
        settings:
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: value:
            if builtins.isBool value then
              "${name}=${if value then "1" else "0"}"
            else if builtins.isList value then
              lib.concatMapStringsSep "\n" (v: "${name}=${toString v}") value
            else
              "${name}=${toString value}"
          ) (lib.filterAttrs (_: v: v != null && v != "") settings)
        );

      # Roaming config reference
      roamingCfg = hostapdCfg.roaming;

      # Build config for a single radio
      mkRadioConfig =
        name: radio:
        let
          hwMode = bandToHwMode radio.band;
          is5GHz = radio.band == "5GHz" || radio.band == "6GHz";

          # For 802.11r, we need FT-PSK or FT-SAE key management
          wpaKeyMgmtWithFT =
            if roamingCfg.enable then
              let
                base = radio.wpaKeyMgmt;
                hasPSK = lib.hasInfix "WPA-PSK" base;
                hasSAE = lib.hasInfix "SAE" base;
              in
              base
              + lib.optionalString (hasPSK && !(lib.hasInfix "FT-PSK" base)) " FT-PSK"
              + lib.optionalString (hasSAE && !(lib.hasInfix "FT-SAE" base)) " FT-SAE"
            else
              radio.wpaKeyMgmt;

          baseSettings = {
            interface = radio.interface;
            driver = radio.driver;
            ssid = radio.ssid;
            hw_mode = hwMode;
            channel = radio.channel;
            country_code = hostapdCfg.countryCode;

            # 802.11n
            ieee80211n = radio.ieee80211n;
            wmm_enabled = true;

            # 802.11ac (5GHz only)
            ieee80211ac = radio.ieee80211ac && is5GHz;

            # 802.11ax
            ieee80211ax = radio.ieee80211ax;

            # Security
            auth_algs = 1;
            wpa = 2;
            wpa_key_mgmt = wpaKeyMgmtWithFT;
            rsn_pairwise = "CCMP";
            wpa_passphrase = radio.wpaPassphrase;
          }
          // lib.optionalAttrs (radio.bssid != null) {
            bssid = radio.bssid;
          }
          // lib.optionalAttrs (radio.bridge != null) {
            bridge = radio.bridge;
          }
          // lib.optionalAttrs (radio.ieee80211n && radio.htCapab != "") {
            ht_capab = radio.htCapab;
          }
          // lib.optionalAttrs (radio.ieee80211ac && is5GHz) (
            {
              vht_oper_chwidth = radio.vhtOperChwidth;
            }
            // lib.optionalAttrs (radio.vhtCapab != "") {
              vht_capab = radio.vhtCapab;
            }
            // lib.optionalAttrs (radio.vhtOperCentrFreqSeg0Idx != null) {
              vht_oper_centr_freq_seg0_idx = radio.vhtOperCentrFreqSeg0Idx;
            }
          )
          # 802.11r Fast Transition
          // lib.optionalAttrs roamingCfg.enable {
            ieee80211r = true;
            mobility_domain = roamingCfg.mobilityDomain;
            ft_over_ds = if roamingCfg.ft_over_ds then 1 else 0;
            ft_psk_generate_local = if roamingCfg.ft_psk_generate_local then 1 else 0;
            pmk_r1_push = 1;
            nas_identifier = "${hostapdCfg.countryCode}${name}";
          }
          # 802.11k Radio Resource Management
          // lib.optionalAttrs roamingCfg.ieee80211k {
            ieee80211k = true;
            rrm_neighbor_report = true;
          }
          # 802.11v BSS Transition Management
          // lib.optionalAttrs roamingCfg.ieee80211v {
            ieee80211v = true;
            bss_transition = roamingCfg.bss_transition;
            wnm_sleep_mode = true;
          }
          // radio.extraSettings;

          # Additional BSSes
          mkBssSection =
            bss:
            let
              bssSettings = {
                bss = bss.interface;
                ssid = bss.ssid;
                auth_algs = 1;
                wpa = 2;
                wpa_key_mgmt = bss.wpaKeyMgmt;
                rsn_pairwise = "CCMP";
                wpa_passphrase = bss.wpaPassphrase;
              }
              // lib.optionalAttrs (bss.bridge != null) {
                bridge = bss.bridge;
              }
              // bss.extraSettings;
            in
            ''

              # Additional BSS: ${bss.ssid}
              ${mkHostapdLines bssSettings}
            '';
        in
        pkgs.writeText "hostapd-${name}.conf" (
          ''
            # Radio: ${name} (${radio.band})
            ${mkHostapdLines baseSettings}
          ''
          + lib.concatMapStrings mkBssSection radio.additionalBSS
        );

      # All enabled radios
      enabledRadios = lib.filterAttrs (_: r: r.enable) hostapdCfg.radios;

      # Collect all interfaces for firewall/DHCP
      allInterfaces = lib.flatten (
        lib.mapAttrsToList (
          _: radio: [ radio.interface ] ++ map (bss: bss.interface) radio.additionalBSS
        ) enabledRadios
      );

      nonBridgedInterfaces = lib.flatten (
        lib.mapAttrsToList (
          _: radio:
          lib.optional (radio.bridge == null) radio.interface
          ++ map (bss: bss.interface) (lib.filter (bss: bss.bridge == null) radio.additionalBSS)
        ) enabledRadios
      );
    in
    {
      options.features.router.hostapd = {
        enable = lib.mkEnableOption "wireless access point (hostapd)";

        countryCode = lib.mkOption {
          type = lib.types.str;
          default = "US";
          description = "ISO 3166-1 country code for regulatory domain (applies to all radios)";
        };

        # Roaming settings (802.11r/k/v)
        roaming = {
          enable = lib.mkEnableOption "fast roaming (802.11r/k/v) for seamless handoff between radios/APs";

          mobilityDomain = lib.mkOption {
            type = lib.types.str;
            default = "a1b2";
            example = "1234";
            description = ''
              Mobility Domain ID (4 hex characters). Must be the same across all APs
              in your roaming network. Generate with: printf '%04x' $RANDOM
            '';
          };

          ft_over_ds = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Enable FT-over-DS (Fast Transition over Distribution System).
              Allows pre-authentication through the wired network.
              Requires all APs to communicate (same bridge/VLAN).
            '';
          };

          ft_psk_generate_local = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Generate FT keys locally. Set to true for simple setups.
              Set to false if using external RADIUS or centralized key management.
            '';
          };

          ieee80211k = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Enable 802.11k (Radio Resource Management).
              Provides clients with neighbor AP reports to help with roaming decisions.
            '';
          };

          ieee80211v = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Enable 802.11v (BSS Transition Management).
              Allows the AP to suggest roaming targets to clients.
            '';
          };

          bss_transition = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable BSS Transition Management (part of 802.11v)";
          };
        };

        radios = lib.mkOption {
          type = lib.types.attrsOf radioSubmodule;
          default = { };
          example = lib.literalExpression ''
            {
              # 2.4GHz radio
              radio24 = {
                interface = "wlan0";
                band = "2.4GHz";
                ssid = "MyNetwork";
                wpaPassphrase = "secretpassword";
                channel = 6;
                bridge = "br-lan";
                ieee80211n = true;
                htCapab = "[HT40+][SHORT-GI-40]";
              };
              # 5GHz radio
              radio5 = {
                interface = "wlan1";
                band = "5GHz";
                ssid = "MyNetwork-5G";
                wpaPassphrase = "secretpassword";
                channel = 36;
                bridge = "br-lan";
                ieee80211n = true;
                ieee80211ac = true;
                ieee80211ax = true;
                vhtOperChwidth = 1;  # 80MHz
                vhtOperCentrFreqSeg0Idx = 42;
              };
            }
          '';
          description = ''
            Configuration for each wireless radio.

            For dual-band cards like MT7916, you typically have two physical interfaces
            (e.g., wlan0 and wlan1). Each needs its own radio configuration.

            Use `iw dev` to list your wireless interfaces and `iw phy` to see capabilities.
          '';
        };

        # Legacy single-radio options (for backwards compatibility)
        interface = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Deprecated: Use radios.<name>.interface instead";
        };

        ssid = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Deprecated: Use radios.<name>.ssid instead";
        };

        wpaPassphrase = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Deprecated: Use radios.<name>.wpaPassphrase instead";
        };

        bridge = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Deprecated: Use radios.<name>.bridge instead";
        };

        # Expose computed values for other modules
        _internal = {
          allInterfaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            internal = true;
            default = allInterfaces;
            description = "All wireless interfaces managed by hostapd";
          };
          nonBridgedInterfaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            internal = true;
            default = nonBridgedInterfaces;
            description = "Wireless interfaces not attached to a bridge";
          };
        };
      };

      config = lib.mkIf enabled {
        assertions =
          # Ensure radios are configured
          [
            {
              assertion = enabledRadios != { };
              message = "router.hostapd: At least one radio must be configured in hostapd.radios";
            }
          ]
          # Per-radio assertions
          ++ lib.flatten (
            lib.mapAttrsToList (name: radio: [
              {
                assertion = radio.ieee80211ac -> (radio.band == "5GHz" || radio.band == "6GHz");
                message = "router.hostapd.radios.${name}: 802.11ac requires 5GHz or 6GHz band";
              }
              {
                assertion = builtins.stringLength radio.wpaPassphrase >= 8;
                message = "router.hostapd.radios.${name}: WPA passphrase must be at least 8 characters";
              }
              {
                assertion = builtins.stringLength radio.wpaPassphrase <= 63;
                message = "router.hostapd.radios.${name}: WPA passphrase must be at most 63 characters";
              }
            ]) enabledRadios
          );

        # Wireless regulatory database
        hardware.wirelessRegulatoryDatabase = true;

        # Create a hostapd service for each radio
        systemd.services = lib.mapAttrs' (
          name: radio:
          lib.nameValuePair "hostapd-${name}" {
            description = "Hostapd Wireless AP - ${name} (${radio.band})";
            after = [
              "sys-subsystem-net-devices-${radio.interface}.device"
              "network.target"
            ];
            bindsTo = [ "sys-subsystem-net-devices-${radio.interface}.device" ];
            wantedBy = [ "multi-user.target" ];

            path = [ pkgs.hostapd ];

            serviceConfig = {
              Type = "forking";
              PIDFile = "/run/hostapd-${name}.pid";
              ExecStart = "${pkgs.hostapd}/bin/hostapd -B -P /run/hostapd-${name}.pid ${mkRadioConfig name radio}";
              ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
              Restart = "on-failure";
              RestartSec = "5s";

              # Hardening
              PrivateTmp = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              NoNewPrivileges = true;
              DeviceAllow = [ "/dev/rfkill rw" ];
              RuntimeDirectory = "hostapd";
            };
          }
        ) enabledRadios;
      };
    };
}
