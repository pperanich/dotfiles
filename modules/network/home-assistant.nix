_: {
  flake.modules = {
    # NixOS system-level Home Assistant configuration
    nixos.home-assistant =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.features.home-assistant;
      in
      {
        options.features.home-assistant = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 8123;
            description = "Port for Home Assistant web interface";
          };
          configDir = lib.mkOption {
            type = lib.types.path;
            default = "/var/lib/hass";
            description = "Home Assistant configuration directory";
          };
          timezone = lib.mkOption {
            type = lib.types.str;
            default = "UTC";
            example = "America/New_York";
            description = "Timezone for Home Assistant";
          };
          enableBluetooth = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Bluetooth support";
          };
        };

        config = {
          services = {
            # Home Assistant service
            home-assistant = {
              enable = true;
              config = {
                homeassistant = {
                  name = "Home";
                  latitude = "!secret latitude";
                  longitude = "!secret longitude";
                  elevation = "!secret elevation";
                  unit_system = "metric";
                  time_zone = cfg.timezone;
                };

                # Basic integrations
                frontend = { };
                config = { };
                history = { };
                logbook = { };
                recorder = { };
                system_health = { };

                # HTTP configuration
                http = {
                  server_port = cfg.port;
                  use_x_forwarded_for = true;
                  trusted_proxies = [
                    "127.0.0.1"
                    "::1"
                  ];
                };

                # Discovery
                discovery = { };
                zeroconf = { };

                # Mobile app support
                mobile_app = { };
              };
              inherit (cfg) configDir;
              package = pkgs.home-assistant.override {
                extraPackages =
                  ps: with ps; [
                    # Additional Python packages
                    psutil
                    colorlog
                  ];
              };
            };

            # Bluetooth support
            blueman.enable = cfg.enableBluetooth;

            # D-Bus (required for Bluetooth)
            dbus.enable = true;
          };

          hardware.bluetooth.enable = cfg.enableBluetooth;

          # Firewall
          networking.firewall.allowedTCPPorts = [
            cfg.port
            1400 # Sonos discovery
          ];

          # Create secrets file template
          systemd.tmpfiles.rules = [
            "f '${cfg.configDir}/secrets.yaml' 0600 hass hass - -"
          ];

          # SOPS secrets (example structure)
          sops.secrets.home-assistant-secrets = {
            mode = "0600";
            owner = "hass";
            group = "hass";
            path = "${cfg.configDir}/secrets.yaml";
          };

          # Required packages
          environment.systemPackages = with pkgs; [
            home-assistant-cli
          ];
        };
      };

    # Home Manager Home Assistant tools
    homeManager.home-assistant =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          home-assistant-cli
        ];
      };
  };
}
