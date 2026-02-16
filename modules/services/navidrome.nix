# Self-hosted music server and streamer (Subsonic/Airsonic compatible)
#
# Indexes a music library and streams via web UI or any Subsonic-compatible
# client (DSub, Symfonium, play:Sub, etc.). Transcodes on the fly.
#
# Access: via Caddy reverse proxy on the router (e.g., navidrome.prestonperanich.com)
# Admin: initial user created through the web UI on first launch
_: {
  flake.modules.nixos.navidrome =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.navidrome;
    in
    {
      options.my.navidrome = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 4533;
          description = "Port for Navidrome web interface.";
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for Navidrome to bind to.";
        };

        musicFolder = lib.mkOption {
          type = lib.types.path;
          example = "/tank/media/music";
          description = "Path to the music library directory.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open the firewall for Navidrome.";
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Environment file for secret ND_* variables (e.g., Spotify, Last.fm keys).";
        };

        extraSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          example = {
            ScanSchedule = "@every 1h";
            TranscodingCacheSize = "512MB";
          };
          description = "Additional Navidrome settings merged into the config. See https://www.navidrome.org/docs/usage/configuration-options/";
        };
      };

      config = {
        services.navidrome = {
          enable = true;
          inherit (cfg) openFirewall environmentFile;
          settings = {
            Address = cfg.address;
            Port = cfg.port;
            MusicFolder = cfg.musicFolder;
          }
          // cfg.extraSettings;
        };
      };
    };
}
