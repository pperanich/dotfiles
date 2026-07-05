# Homepage dashboard — landing page for all internal services
{ lib, ... }:
let
  inherit (lib.my.homelab) mkSub;

  # Homepage dashboard service entry
  mkDashboardService =
    {
      name,
      icon,
      sub,
      desc,
      path ? "",
    }:
    {
      ${name} = {
        inherit icon;
        href = "https://${mkSub sub}${path}";
        description = desc;
      };
    };
in
{
  services.homepage-dashboard = {
    enable = true;
    # Internal-only — not exposed to WAN, Caddy handles access control
    allowedHosts = "*";
    settings = {
      title = "Homelab";
      favicon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homepage.png";
      headerStyle = "clean";
      layout = {
        Network = {
          style = "row";
          columns = 4;
        };
        Media = {
          style = "row";
          columns = 3;
        };
        Services = {
          style = "row";
          columns = 3;
        };
      };
    };
    services = [
      {
        "Network" = map mkDashboardService [
          {
            name = "Unifi";
            icon = "unifi";
            sub = "unifi";
            desc = "Network controller";
          }
          {
            name = "ntopng";
            icon = "ntopng";
            sub = "ntopng";
            desc = "Network monitoring";
          }
          {
            name = "Grafana";
            icon = "grafana";
            sub = "grafana";
            desc = "Metrics, logs & alerts";
          }
          {
            name = "Alertmanager";
            icon = "alertmanager";
            sub = "alerts";
            desc = "Alert routing & silences";
          }
        ];
      }
      {
        "Media" = map mkDashboardService [
          {
            name = "Jellyfin";
            icon = "jellyfin";
            sub = "jellyfin";
            desc = "Movies, TV & music streaming";
          }
          {
            name = "Navidrome";
            icon = "navidrome";
            sub = "navidrome";
            desc = "Music server";
          }
          {
            name = "Audiobookshelf";
            icon = "audiobookshelf";
            sub = "audiobookshelf";
            desc = "Audiobooks & podcasts";
          }
        ];
      }
      {
        "Services" = map mkDashboardService [
          {
            name = "Immich";
            icon = "immich";
            sub = "immich";
            desc = "Photo & video backup";
          }
          {
            name = "Nextcloud";
            icon = "nextcloud";
            sub = "nextcloud";
            desc = "File sync & collaboration";
          }
          {
            name = "OpenCloud";
            icon = "open-cloud";
            sub = "opencloud";
            desc = "File sync";
          }
          {
            name = "Vaultwarden";
            icon = "vaultwarden";
            sub = "vault";
            desc = "Password manager";
          }
          {
            name = "Scan";
            icon = "scrutiny"; # placeholder icon; swap later
            sub = "scan";
            desc = "Network scanner (Canon TR4500)";
          }
          {
            name = "Paperless";
            icon = "paperless-ngx";
            sub = "paperless";
            desc = "Document archive & OCR";
          }
          {
            name = "DocuSeal";
            icon = "docuseal";
            sub = "docuseal";
            desc = "Document signing";
          }
          {
            name = "Radicale";
            icon = "radicale";
            sub = "dav";
            desc = "Calendar & contacts sync";
          }
          {
            name = "Home Assistant";
            icon = "home-assistant";
            sub = "hass";
            desc = "Home automation";
          }
          {
            name = "Gitea";
            icon = "gitea";
            sub = "gitea";
            desc = "Self-hosted git";
          }
          {
            name = "Vaultwarden Admin";
            icon = "vaultwarden";
            sub = "vault-admin";
            path = "/admin";
            desc = "Admin panel (internal only)";
          }
        ];
      }
    ];
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
    ];
  };
}
