# Self-hosted audiobook and podcast server
#
# Streams audiobooks and podcasts with progress tracking, bookmarks,
# and multi-user support. Metadata fetched automatically.
#
# Access: via Caddy reverse proxy on the router (e.g., audiobookshelf.prestonperanich.com)
# Admin: initial setup through the web UI on first launch
_: {
  flake.modules.nixos.audiobookshelf =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.audiobookshelf;
    in
    {
      options.features.audiobookshelf = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 8000;
          description = "Port for Audiobookshelf web interface.";
        };

        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for Audiobookshelf to bind to.";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "audiobookshelf";
          description = "Data directory name inside /var/lib for config and metadata.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to open the firewall for Audiobookshelf.";
        };

        mediaDirectories = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          example = [
            "/tank/media/audiobooks"
            "/tank/media/podcasts"
          ];
          description = "Media directories Audiobookshelf needs access to (configured as libraries in the web UI).";
        };
      };

      config = {
        services.audiobookshelf = {
          enable = true;
          host = cfg.address;
          inherit (cfg) port dataDir openFirewall;
        };

        # Ensure media directories exist with correct ownership
        systemd.tmpfiles.settings."10-audiobookshelf" = lib.listToAttrs (
          map (dir: {
            name = dir;
            value."d" = {
              user = "audiobookshelf";
              group = "audiobookshelf";
              mode = "0750";
            };
          }) cfg.mediaDirectories
        );
      };
    };
}
