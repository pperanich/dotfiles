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
      internal = cfg._internal;
      enabled = cfg.enable && hostapdCfg.enable;

      # WiFi networks from the networks module (when useNetworks = true)
      wifiNetworks = internal.wifiNetworks or [ ];
      useNetworks = hostapdCfg.useNetworks && wifiNetworks != [ ];

      # Get password file path from sops secret name
      getPasswordFile =
        secretName: if secretName != null then config.sops.secrets.${secretName}.path or null else null;

      # First WiFi network becomes the primary BSS, rest become additionalBSS
      primaryNetwork = if wifiNetworks != [ ] then builtins.head wifiNetworks else null;
      additionalNetworks = if wifiNetworks != [ ] then builtins.tail wifiNetworks else [ ];

      # Generate additionalBSS entries for a radio from networks
      # bssIndex is used to generate unique locally-administered BSSIDs
      mkNetworkBSS =
        radioInterface: bssIndex: net:
        let
          # Add FT (Fast Transition) to key management if roaming enabled
          keyMgmt =
            if net.roaming or false then
              # Add FT variants for roaming support
              if net.wpaKeyMgmt == "SAE WPA-PSK" then
                "SAE WPA-PSK FT-SAE FT-PSK"
              else if net.wpaKeyMgmt == "SAE" then
                "SAE FT-SAE"
              else if net.wpaKeyMgmt == "WPA-PSK" then
                "WPA-PSK FT-PSK"
              else
                net.wpaKeyMgmt
            else
              net.wpaKeyMgmt;
        in
        {
          interface = "${radioInterface}_${net.name}";
          inherit (net) ssid;
          wpaKeyMgmt = keyMgmt;
          wpaPassphraseFile = getPasswordFile net.passwordSecret;
          inherit (net) bridge;
          # Use locally administered MAC (02:xx:xx:xx:xx:idx) to avoid BSSID mask issues
          # The 02 prefix sets the locally-administered bit
          bssid = "02:00:00:00:00:0${toString bssIndex}";
          roaming = net.roaming or false;
          extraSettings =
            lib.optionalAttrs net.clientIsolation { ap_isolate = 1; }
            // lib.optionalAttrs (net.roaming or false) {
              # 802.11r Fast Transition
              mobility_domain = hostapdCfg.roaming.mobilityDomain;
              ft_over_ds = 0;
              ft_psk_generate_local = 1;
              nas_identifier = "${hostapdCfg.countryCode}${radioInterface}_${net.name}";
              # 802.11k Radio Resource Management
              rrm_neighbor_report = 1;
              rrm_beacon_report = 1;
              # 802.11v BSS Transition Management
              bss_transition = 1;
              wnm_sleep_mode = 1;
            };
        };

      # Radio submodule type (each radio = one hostapd instance)
      radioSubmodule = lib.types.submodule (_: {
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
            default = "";
            example = "MyNetwork-5G";
            description = "Wireless network name (SSID). Optional when hostapd.useNetworks = true.";
          };

          wpaPassphrase = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "WPA2/WPA3 passphrase (8-63 characters). Optional when hostapd.useNetworks = true.";
          };

          wpaPassphraseFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            example = "/run/secrets/wifi_passphrase";
            description = ''
              Path to a file containing the WPA passphrase (8-63 characters).
              Optional when hostapd.useNetworks = true.
            '';
          };

          wpaKeyMgmt = lib.mkOption {
            type = lib.types.str;
            default = "WPA-PSK";
            example = "SAE WPA-PSK";
            description = "Key management. 'SAE' for WPA3, 'WPA-PSK' for WPA2, 'SAE WPA-PSK' for transition mode.";
          };

          ieee80211w = lib.mkOption {
            type = lib.types.enum [
              0
              1
              2
            ];
            default = 0;
            example = 1;
            description = ''
              Management Frame Protection (MFP/PMF). Required for WPA3/SAE.
              0 = disabled, 1 = optional (for transition mode), 2 = required (WPA3 only).
              Automatically set to 1 when SAE is in wpaKeyMgmt for transition mode.
            '';
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

          # WiFi 6 (HE) specific options
          heSuBeamformer = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable HE single-user beamformer (requires hardware support)";
          };

          heSuBeamformee = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable HE single-user beamformee";
          };

          heMuBeamformer = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable HE multi-user beamformer (MU-MIMO, requires hardware support)";
          };

          heBssColor = lib.mkOption {
            type = lib.types.ints.between 1 63;
            default = 1;
            description = "HE BSS color for OBSS interference management (1-63)";
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
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "WPA passphrase for this BSS. Mutually exclusive with wpaPassphraseFile.";
                  };
                  wpaPassphraseFile = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Path to file containing WPA passphrase for this BSS.";
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
      });

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
            inherit (radio) interface;
            inherit (radio) driver;
            inherit (radio) ssid;
            hw_mode = hwMode;
            inherit (radio) channel;
            country_code = hostapdCfg.countryCode;

            # Control interface for hostapd_cli
            ctrl_interface = "/run/hostapd";
            ctrl_interface_group = 0; # root only

            # 802.11n
            inherit (radio) ieee80211n;
            wmm_enabled = true;

            # 802.11ac (5GHz only)
            ieee80211ac = radio.ieee80211ac && is5GHz;

            # 802.11ax
            inherit (radio) ieee80211ax;
          }
          # WiFi 6 (HE) options - only when 802.11ax is enabled
          // lib.optionalAttrs radio.ieee80211ax {
            he_su_beamformer = if radio.heSuBeamformer then 1 else 0;
            he_su_beamformee = if radio.heSuBeamformee then 1 else 0;
            he_mu_beamformer = if radio.heMuBeamformer then 1 else 0;
            he_bss_color = radio.heBssColor;
          }
          // {
            # Security
            auth_algs = 1;
            wpa = 2;
            wpa_key_mgmt = wpaKeyMgmtWithFT;
            rsn_pairwise = "CCMP";

            # Management Frame Protection (required for SAE/WPA3)
            # Auto-enable if SAE is used and user hasn't explicitly set it
            ieee80211w =
              let
                hasSAE = lib.hasInfix "SAE" radio.wpaKeyMgmt;
                userValue = radio.ieee80211w;
              in
              if userValue != 0 then
                userValue
              else if hasSAE then
                1 # Auto-enable for SAE transition mode
              else
                0;
          }
          # Passphrase: either direct or from file (use placeholder for file-based)
          // lib.optionalAttrs (radio.wpaPassphrase != null) {
            wpa_passphrase = radio.wpaPassphrase;
          }
          // lib.optionalAttrs (radio.wpaPassphraseFile != null) {
            # Placeholder that will be replaced at runtime by ExecStartPre
            wpa_passphrase = "@WPA_PASSPHRASE@";
          }
          // lib.optionalAttrs (radio.bssid != null) {
            inherit (radio) bssid;
          }
          // lib.optionalAttrs (radio.bridge != null) {
            inherit (radio) bridge;
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
          # Note: ieee80211r is NOT a valid hostapd.conf option - it's an OpenWrt UCI abstraction.
          # 802.11r is enabled implicitly when wpa_key_mgmt includes FT-PSK or FT-SAE.
          // lib.optionalAttrs roamingCfg.enable {
            mobility_domain = roamingCfg.mobilityDomain;
            nas_identifier = "${hostapdCfg.countryCode}${name}";
            ft_over_ds = if roamingCfg.ft_over_ds then 1 else 0;
            ft_psk_generate_local = if roamingCfg.ft_psk_generate_local then 1 else 0;
            reassociation_deadline = 1000;
            pmk_r1_push = 1;
          }
          # 802.11k Radio Resource Management (requires roaming enabled)
          # Note: ieee80211k is an OpenWrt UCI abstraction, not a hostapd.conf option.
          # The actual options are rrm_neighbor_report and rrm_beacon_report.
          // lib.optionalAttrs (roamingCfg.enable && roamingCfg.ieee80211k) {
            rrm_neighbor_report = 1;
            rrm_beacon_report = 1;
          }
          # 802.11v BSS Transition Management (requires roaming enabled)
          # Note: ieee80211v is an OpenWrt UCI abstraction, not a hostapd.conf option.
          # The actual options are bss_transition and wnm_sleep_mode.
          // lib.optionalAttrs (roamingCfg.enable && roamingCfg.ieee80211v) {
            bss_transition = if roamingCfg.bss_transition then 1 else 0;
            wnm_sleep_mode = 1;
          }
          // radio.extraSettings;

          # Additional BSSes
          mkBssSection =
            bss:
            let
              # Handle both submodule BSSes (have wpaPassphrase attr) and network-generated BSSes (don't have it)
              hasWpaPassphrase = bss.wpaPassphrase or null;
              hasWpaPassphraseFile = bss.wpaPassphraseFile or null;
              hasBridge = bss.bridge or null;
              hasBssid = bss.bssid or null;
              bssExtraSettings = bss.extraSettings or { };
              # BSS settings (excluding 'bss' which must come first)
              bssSettings = {
                inherit (bss) ssid;
                auth_algs = 1;
                wpa = 2;
                wpa_key_mgmt = bss.wpaKeyMgmt;
                rsn_pairwise = "CCMP";
              }
              // lib.optionalAttrs (hasBssid != null) {
                bssid = hasBssid;
              }
              // lib.optionalAttrs (hasWpaPassphrase != null) {
                wpa_passphrase = hasWpaPassphrase;
              }
              // lib.optionalAttrs (hasWpaPassphraseFile != null) {
                wpa_passphrase = "@BSS_WPA_PASSPHRASE_${bss.interface}@";
              }
              // lib.optionalAttrs (hasBridge != null) {
                bridge = hasBridge;
              }
              // bssExtraSettings;
            in
            ''

              # Additional BSS: ${bss.ssid}
              bss=${bss.interface}
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

      # All enabled radios (raw from config)
      rawEnabledRadios = lib.filterAttrs (_: r: r.enable) hostapdCfg.radios;

      # Apply network configuration to radios when useNetworks = true
      # Each radio gets: primary SSID from first network, additionalBSS from rest
      effectiveRadios =
        if useNetworks then
          lib.mapAttrs (
            _name: radio:
            radio
            // {
              # Primary BSS from first network
              inherit (primaryNetwork) ssid;
              inherit (primaryNetwork) bridge;
              inherit (primaryNetwork) wpaKeyMgmt;
              wpaPassphraseFile = getPasswordFile primaryNetwork.passwordSecret;
              # Additional BSSes from remaining networks (with indexed BSSIDs)
              additionalBSS =
                radio.additionalBSS
                ++ lib.imap1 (idx: net: mkNetworkBSS radio.interface idx net) additionalNetworks;
            }
          ) rawEnabledRadios
        else
          rawEnabledRadios;

      # Use effective radios everywhere
      enabledRadios = effectiveRadios;

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

        useNetworks = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Auto-configure WiFi networks from features.router.networks.
            When enabled, radios don't need ssid/bridge/additionalBSS - they're
            auto-generated from networks with wifi.enable = true.
          '';
        };

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
            # When useNetworks is true, ensure networks are configured
            {
              assertion = !hostapdCfg.useNetworks || wifiNetworks != [ ];
              message = "router.hostapd: useNetworks requires at least one network with wifi.enable = true";
            }
          ]
          # Per-radio assertions (on effective radios, so they have network config applied)
          ++ lib.flatten (
            lib.mapAttrsToList (name: radio: [
              {
                assertion = radio.ieee80211ac -> (radio.band == "5GHz" || radio.band == "6GHz");
                message = "router.hostapd.radios.${name}: 802.11ac requires 5GHz or 6GHz band";
              }
              {
                # Password required (either from radio config or from networks)
                assertion = (radio.wpaPassphrase != null) || (radio.wpaPassphraseFile != null);
                message = "router.hostapd.radios.${name}: Either wpaPassphrase or wpaPassphraseFile must be set";
              }
              {
                assertion = !((radio.wpaPassphrase != null) && (radio.wpaPassphraseFile != null));
                message = "router.hostapd.radios.${name}: wpaPassphrase and wpaPassphraseFile are mutually exclusive";
              }
              {
                assertion = (radio.wpaPassphrase == null) || (builtins.stringLength radio.wpaPassphrase >= 8);
                message = "router.hostapd.radios.${name}: WPA passphrase must be at least 8 characters";
              }
              {
                assertion = (radio.wpaPassphrase == null) || (builtins.stringLength radio.wpaPassphrase <= 63);
                message = "router.hostapd.radios.${name}: WPA passphrase must be at most 63 characters";
              }
              {
                # SSID required (either from radio config or from networks)
                assertion = radio.ssid != "";
                message = "router.hostapd.radios.${name}: ssid must be set (or use hostapd.useNetworks = true)";
              }
            ]) enabledRadios
          );

        # Wireless regulatory database
        hardware.wirelessRegulatoryDatabase = true;

        # Create a hostapd service for each radio
        systemd.services = lib.mapAttrs' (
          name: radio:
          let
            configFile = mkRadioConfig name radio;
            usesPassphraseFile = radio.wpaPassphraseFile != null;
            runtimeConfigPath = "/run/hostapd/hostapd-${name}.conf";

            # Collect all BSS entries that need passphrase substitution
            bssWithPassphraseFiles = lib.filter (
              bss: (bss.wpaPassphraseFile or null) != null
            ) radio.additionalBSS;

            # Generate sed commands for each BSS passphrase
            bssSubstitutions = lib.concatMapStringsSep "\n" (bss: ''
              BSS_PASS_${lib.replaceStrings [ "-" ] [ "_" ] bss.interface}=$(cat "${bss.wpaPassphraseFile}")
              ${pkgs.gnused}/bin/sed -i "s|@BSS_WPA_PASSPHRASE_${bss.interface}@|$BSS_PASS_${
                lib.replaceStrings [ "-" ] [ "_" ] bss.interface
              }|g" "${runtimeConfigPath}"
            '') bssWithPassphraseFiles;

            # Script to substitute passphrase from file
            prepareConfig = pkgs.writeShellScript "hostapd-${name}-prepare" ''
              set -euo pipefail
              ${
                if usesPassphraseFile then
                  ''
                    PASSPHRASE=$(cat "${radio.wpaPassphraseFile}")
                    ${pkgs.gnused}/bin/sed "s|@WPA_PASSPHRASE@|$PASSPHRASE|g" "${configFile}" > "${runtimeConfigPath}"
                  ''
                else
                  ''
                    cp "${configFile}" "${runtimeConfigPath}"
                  ''
              }
              ${bssSubstitutions}
              chmod 600 "${runtimeConfigPath}"
            '';

            # Workaround: hostapd sometimes fails to add BSS interfaces to bridges
            # This script ensures all interfaces are in their correct bridges
            # Run in background to not block service startup
            bssWithBridges = lib.filter (bss: (bss.bridge or null) != null) radio.additionalBSS;
            ensureBridges = pkgs.writeShellScript "hostapd-${name}-ensure-bridges" ''
              (
                # Wait for hostapd to create virtual interfaces
                sleep 5
                ${lib.concatMapStringsSep "\n" (bss: ''
                  if ${pkgs.iproute2}/bin/ip link show ${bss.interface} &>/dev/null; then
                    ${pkgs.iproute2}/bin/ip link set ${bss.interface} master ${bss.bridge} 2>/dev/null || true
                  fi
                '') bssWithBridges}
              ) &
            '';
          in
          lib.nameValuePair "hostapd-${name}" {
            description = "Hostapd Wireless AP - ${name} (${radio.band})";
            after = [
              "sys-subsystem-net-devices-${radio.interface}.device"
              "network.target"
            ]
            ++ lib.optional usesPassphraseFile "sops-nix.service";
            bindsTo = [ "sys-subsystem-net-devices-${radio.interface}.device" ];
            wantedBy = [ "multi-user.target" ];

            path = [ pkgs.hostapd ];

            serviceConfig = {
              # Use simple type (foreground) - forking mode times out during HT_SCAN
              Type = "simple";
              ExecStartPre = "${prepareConfig}";
              ExecStart = "${pkgs.hostapd}/bin/hostapd ${runtimeConfigPath}";
              ExecStartPost = lib.mkIf (bssWithBridges != [ ]) "${ensureBridges}";
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
              RuntimeDirectoryMode = "0750";
            };
          }
        ) enabledRadios;
      };
    };
}
