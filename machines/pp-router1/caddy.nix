# Caddy reverse proxy + the Cloudflare DNS records that must stay in sync
# with its vhosts. HTTPS via DNS-01 (caddyDns01 module) — no public ports.
# Access from LAN (10.0.0.1) and WireGuard VPN.
#
# Records point to private IPs — unreachable from the public internet.
# LAN clients resolve via Unbound (10.0.0.1), VPN clients via public DNS +
# WireGuard. Synced every 12h via systemd timer. Manual: systemctl start
# cf-dns-sync. When adding a new virtualHost, add a matching record.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  wgPrefix = config.clan.core.vars.generators.wireguard-network-pp-wg.files.prefix.value;
  wgAddress = "${wgPrefix}::1";
  routerIp = config.my.router.lan.address;
  nasHost = "pp-nas1.${config.my.router.dhcp.domainName}";
  inherit (lib.my.homelab) publicDomain mkSub;

  # Generate A + AAAA record pairs pointing subdomains to the router (LAN + WireGuard)
  mkDnsRecords =
    subdomains:
    lib.concatMap (sub: [
      {
        type = "A";
        name = mkSub sub;
        content = routerIp;
      }
      {
        type = "AAAA";
        name = mkSub sub;
        content = wgAddress;
      }
    ]) subdomains;

  # Caddy vhost listening on LAN + WireGuard with custom config
  mkVhost = extraConfig: {
    listenAddresses = [
      routerIp
      wgAddress
    ];
    inherit extraConfig;
  };

  # Simple reverse proxy vhost (LAN + WireGuard)
  mkProxy =
    backend:
    mkVhost ''
      reverse_proxy ${backend}
    '';

  # Proxy to the NAS's own Caddy over TLS (split-horizon: LAN clients reach
  # it directly, this vhost carries the WG/hairpin path). Dial the stable
  # .home.arpa name but verify the upstream cert against the public name —
  # resolving the public name here could self-loop via our own vhost.
  mkNasProxy =
    fqdn: extra:
    mkVhost ''
      reverse_proxy https://${nasHost} {
        transport http {
          tls_server_name ${fqdn}
        }
      }
      ${extra}
    '';
in
{
  my.caddyDns01.enable = true;

  # Per-request metrics (latency/status per vhost) on the admin endpoint,
  # scraped by the local Prometheus as job "caddy"
  services.caddy.globalConfig = ''
    servers {
      metrics
    }
  '';

  my.cloudflareDns = {
    enable = true;
    zone = publicDomain;
    records =
      mkDnsRecords [
        "feedme" # temporary address for feedme backend
        "ntopng" # network monitoring
        "unifi" # Ubiquiti controller
        "immich" # photo/video management (pp-nas1)
        "nextcloud" # file sync & collaboration (pp-nas1)
        "opencloud" # file sync trial (pp-nas1)
        "jellyfin" # media server (pp-nas1)
        "navidrome" # music server (pp-nas1)
        "audiobookshelf" # audiobooks & podcasts (pp-nas1)
        "scan" # scanservjs web UI (pp-nas1)
        "paperless" # document archive (pp-nas1)
        "docuseal" # document signing (pp-nas1)
        "dav" # radicale caldav/carddav (pp-nas1)
        "hass" # home assistant (pp-nas1)
        "home" # dashboard (pp-router1)
        "grafana" # observability dashboard
        "alerts" # alertmanager UI
        "vault-admin" # vaultwarden admin panel (pp-router1)
        "gitea" # self-hosted git (pp-router1)
      ]
      ++ [
        # Mail deliverability (SPF + DKIM + DMARC)
        {
          type = "TXT";
          name = publicDomain;
          # TODO: Update with Resend-provided SPF after domain verification
          content = "v=spf1 include:_spf.resend.com ~all";
        }
        {
          type = "TXT";
          name = "_dmarc.${publicDomain}";
          content = "v=DMARC1; p=none; rua=mailto:dmarc@${publicDomain}";
        }
      ];
  };

  services.caddy.virtualHosts = {
    # --- Personal site (static, built by bun2nix) ---
    "${publicDomain}" = mkVhost ''
      root * ${pkgs.personal-site}
      file_server
    '';
    "${mkSub "www"}" = mkVhost ''
      redir https://${publicDomain}{uri} permanent
    '';

    "${mkSub "feedme"}" = mkVhost ''
      reverse_proxy http://pp-ml1.${config.my.router.dhcp.domainName}:3000 {
        header_up X-Forwarded-Proto {scheme}
      }
      request_body {
        max_size 16G
      }
    '';

    # --- Simple reverse proxies (router-local services) ---
    "${mkSub "home"}" = mkProxy "localhost:8082";
    "${mkSub "grafana"}" = mkProxy "localhost:3010";
    "${mkSub "alerts"}" = mkProxy "localhost:9093";
    "${mkSub "ntopng"}" = mkProxy "localhost:3000";
    "${mkSub "vault"}" = mkProxy "localhost:${toString config.my.vaultwarden.port}";
    "${mkSub "vault-admin"}" = mkProxy "localhost:${toString config.my.vaultwarden.port}";

    # Gitea web UI + HTTPS clone. LFS uploads benefit from a high body cap.
    "${mkSub "gitea"}" = mkVhost ''
      reverse_proxy http://localhost:${toString config.my.gitea.port} {
        header_up X-Forwarded-Proto {scheme}
      }
      request_body {
        max_size 5G
      }
    '';

    # Unifi controller (self-signed cert, requires origin header rewrite for CSRF)
    "${mkSub "unifi"}" = mkVhost ''
      reverse_proxy https://localhost:8443 {
        transport http {
          tls_insecure_skip_verify
        }
        header_up X-Forwarded-Proto {scheme}
        header_up Origin https://localhost:8443
        header_up Referer https://localhost:8443
      }
    '';

    # --- NAS services (pp-nas1) ---
    # TLS re-proxy to the NAS's local Caddy; body caps live NAS-side.
    # LAN clients bypass these vhosts entirely via split-horizon DNS.
    "${mkSub "immich"}" = mkNasProxy (mkSub "immich") ''
      request_body {
        max_size 50G
      }
    '';
    "${mkSub "nextcloud"}" = mkNasProxy (mkSub "nextcloud") ''
      request_body {
        max_size 16G
      }
    '';
    "${mkSub "opencloud"}" = mkNasProxy (mkSub "opencloud") ''
      request_body {
        max_size 16G
      }
    '';
    "${mkSub "audiobookshelf"}" = mkNasProxy (mkSub "audiobookshelf") ''
      request_body {
        max_size 10G
      }
    '';
    "${mkSub "paperless"}" = mkNasProxy (mkSub "paperless") ''
      request_body {
        max_size 1G
      }
    '';
    "${mkSub "docuseal"}" = mkNasProxy (mkSub "docuseal") ''
      request_body {
        max_size 1G
      }
    '';
    # Radicale CalDAV/CardDAV — auth happens at the NAS Caddy (basic auth)
    "${mkSub "dav"}" = mkNasProxy (mkSub "dav") "";
    # scanservjs — Canon TR4500 web scan UI
    "${mkSub "scan"}" = mkNasProxy (mkSub "scan") "";
    # Home Assistant (websockets proxied automatically)
    "${mkSub "hass"}" = mkNasProxy (mkSub "hass") "";
    # Media servers
    "${mkSub "jellyfin"}" = mkNasProxy (mkSub "jellyfin") "";
    "${mkSub "navidrome"}" = mkNasProxy (mkSub "navidrome") "";

    # --- Cloudflare Tunnel listeners (localhost only) ---
    # Personal site (public via tunnel)
    "http://:8224" = {
      listenAddresses = [ "127.0.0.1" ];
      extraConfig = ''
        root * ${pkgs.personal-site}
        file_server
      '';
    };

    # Vaultwarden (public via tunnel, blocks /admin)
    "http://:8223" = {
      listenAddresses = [ "127.0.0.1" ];
      extraConfig = ''
        # Block /admin from public access (Cloudflare Tunnel)
        handle /admin* {
          respond "Forbidden" 403
        }
        handle {
          reverse_proxy localhost:${toString config.my.vaultwarden.port}
        }
      '';
    };
  };
}
