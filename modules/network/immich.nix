_: {
  # NixOS system-level Immich photo management configuration
  flake.modules.nixos.immich =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.immich;
    in
    {
      options.features.immich = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 2283;
          description = "Port for Immich web interface";
        };
        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for Immich to bind to";
        };
        mediaLocation = lib.mkOption {
          type = lib.types.path;
          default = "/tank/appdata/immich";
          description = "Directory for Immich media storage";
        };
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open the firewall for Immich";
        };
        enableHardwareTranscoding = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable hardware-accelerated video transcoding (requires compatible GPU)";
        };
        enableMachineLearning = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable ML features (smart search, face detection). Pulls in PyTorch (~2GB).";
        };
      };

      config = {
        # Immich service
        services.immich = {
          enable = true;
          inherit (cfg) port;
          host = cfg.address;
          inherit (cfg) mediaLocation;
          inherit (cfg) openFirewall;
          machine-learning.enable = cfg.enableMachineLearning;
          accelerationDevices = lib.mkIf cfg.enableHardwareTranscoding null;
        };

        # Hardware acceleration support
        hardware.graphics.enable = lib.mkIf cfg.enableHardwareTranscoding true;

        users.users.immich.extraGroups = lib.mkIf cfg.enableHardwareTranscoding [
          "video"
          "render"
        ];

        # Note: services.immich.openFirewall handles firewall rules natively
      };
    };
}
