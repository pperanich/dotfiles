# Self-hosted media server for movies, TV shows, music, and live TV
#
# Streams media to any device with no subscriptions or central servers.
# Supports hardware-accelerated transcoding via VAAPI, QSV, NVENC, etc.
#
# Access: via Caddy reverse proxy on the router (e.g., jellyfin.prestonperanich.com)
# Admin: initial setup wizard on first launch
_: {
  flake.modules.nixos.jellyfin =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.jellyfin;
    in
    {
      options.my.jellyfin = {
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/jellyfin";
          description = "Base data directory for Jellyfin metadata and configuration.";
        };

        cacheDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/cache/jellyfin";
          description = "Directory for Jellyfin transcoding cache.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open the firewall for Jellyfin (HTTP 8096, HTTPS 8920, discovery 1900/7359).";
        };

        enableHardwareAcceleration = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable hardware-accelerated video transcoding (requires compatible GPU).";
        };

        hardwareAccelerationType = lib.mkOption {
          type = lib.types.enum [
            "vaapi"
            "qsv"
            "nvenc"
            "v4l2m2m"
            "rkmpp"
          ];
          default = "vaapi";
          description = "Hardware acceleration method. VAAPI works with most Intel/AMD GPUs.";
        };

        hardwareDevice = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = "/dev/dri/renderD128";
          description = "Path to the GPU render device for hardware transcoding.";
        };

        mediaDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          example = [
            "/tank/media/movies"
            "/tank/media/tv"
            "/tank/media/music"
          ];
          description = "Media directories the Jellyfin user needs read access to.";
        };
      };

      config = {
        services.jellyfin = {
          enable = true;
          inherit (cfg) dataDir cacheDir openFirewall;
          hardwareAcceleration = lib.mkIf cfg.enableHardwareAcceleration {
            enable = true;
            type = cfg.hardwareAccelerationType;
            device = cfg.hardwareDevice;
          };
        };

        # GPU access for hardware transcoding
        hardware.graphics.enable = lib.mkIf cfg.enableHardwareAcceleration true;

        users.users.jellyfin.extraGroups = lib.mkIf cfg.enableHardwareAcceleration [
          "video"
          "render"
        ];

        # Ensure media directories exist with correct ownership
        systemd.tmpfiles.settings."10-jellyfin" = lib.listToAttrs (
          map (dir: {
            name = dir;
            value."d" = {
              user = "jellyfin";
              group = "jellyfin";
              mode = "0755";
            };
          }) cfg.mediaDirectories
        );
      };
    };
}
