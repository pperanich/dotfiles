# Home automation hub for devices on the IoT VLAN.
#
# Runs on the main VLAN; reaches IoT devices via the router's main→iot
# allow rule. Onboarding wizard runs on first launch.
# Access: via Caddy reverse proxy on the router (hass.prestonperanich.com)
_: {
  flake.modules.nixos.homeAssistant =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.homeAssistant;
    in
    {
      options.my.homeAssistant = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 8123;
          description = "Port for the Home Assistant web interface";
        };

        configDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/hass";
          description = "Directory for Home Assistant configuration and state";
        };

        trustedProxies = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "10.0.0.1" ];
          description = "Reverse proxies allowed to set X-Forwarded-For";
        };

        extraComponents = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional Home Assistant components beyond the defaults";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the firewall for the Home Assistant web interface";
        };
      };

      config = {
        # The !include'd files must exist or HA boots into recovery mode
        systemd.tmpfiles.rules = [
          "f ${cfg.configDir}/automations.yaml 0644 hass hass -"
          "f ${cfg.configDir}/scenes.yaml 0644 hass hass -"
          "f ${cfg.configDir}/scripts.yaml 0644 hass hass -"
        ];

        services.home-assistant = {
          enable = true;
          inherit (cfg) configDir openFirewall;
          extraComponents = [
            "default_config"
            "met"
            "esphome"
            "radio_browser"
            "isal"
          ]
          ++ cfg.extraComponents;
          config = {
            default_config = { };
            http = {
              server_port = cfg.port;
              trusted_proxies = cfg.trustedProxies;
              use_x_forwarded_for = cfg.trustedProxies != [ ];
            };
            # UI-managed automations/scenes/scripts stay editable
            "automation ui" = "!include automations.yaml";
            "scene ui" = "!include scenes.yaml";
            "script ui" = "!include scripts.yaml";
          };
        };
      };
    };
}
