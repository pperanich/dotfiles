# Caddy reverse proxy + the Cloudflare DNS records that must stay in sync
# with its vhosts. HTTPS via DNS-01 (caddyDns01 module) — no public ports.
# Access from LAN (10.0.0.1) and the tailnet.
#
# Records point to private IPs — unreachable from the public internet.
# LAN clients resolve via Unbound (10.0.0.1), tailnet clients via public DNS +
# Tailscale. Synced every 12h via systemd timer. Manual: systemctl start
# cf-dns-sync. When adding a new virtualHost, add a matching record.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  routerIp = config.my.router.lan.address;
  nasHost = "pp-nas1.${config.my.router.dhcp.domainName}";
  inherit (lib.my.homelab) publicDomain mkSub;
  caddyCrowdsecEnabled = config.my.router.ids.enable && config.my.router.ids.caddyBouncer.enable;
  mkPublicLogFormat = name: ''
    output file /var/log/caddy/public-${name}.log {
      mode 0640
    }
  '';

  # AAAA-only records pointing subdomains at the router's tailnet ULA; LAN
  # clients get split-horizon A answers from Unbound instead.
  mkDnsRecords =
    subdomains:
    map (sub: {
      type = "AAAA";
      name = mkSub sub;
      content = config.my.headscale.routerTailscaleIpv6;
    }) subdomains;

  # Caddy vhost listening on LAN + Tailscale with custom config
  mkVhost = extraConfig: {
    listenAddresses = [
      routerIp
      config.my.headscale.routerTailscaleIpv4
      config.my.headscale.routerTailscaleIpv6
    ];
    inherit extraConfig;
  };

  # Simple reverse proxy vhost (LAN + Tailscale)
  mkProxy =
    backend:
    mkVhost ''
      reverse_proxy ${backend}
    '';

  # Proxy to the NAS's own Caddy over TLS (split-horizon: LAN clients reach
  # it directly, this vhost carries the tailnet/hairpin path). Dial the stable
  # .home.arpa name but verify the upstream cert against the public name —
  # resolving the public name here could self-loop via our own vhost.
  mkNasProxy =
    fqdn: extra:
    mkVhost ''
      reverse_proxy https://${nasHost} {
        # Caddy >= 2.9 rewrites Host to the upstream dial address when
        # proxying to an https hostname; the NAS Caddy routes on the
        # original name, so pin it or every request 200s with empty body
        header_up Host {host}
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
  # scraped by the local Prometheus as job "caddy".
  # Only trust forwarded client IP headers from loopback (cloudflared tunnel
  # listeners) so LAN/tailnet peers cannot spoof X-Forwarded-For.
  # Disable automatic HTTP->HTTPS redirects on :80: port 80 is closed on both
  # WAN and LAN, and mixing IP-bound :443 vhosts with the wildcard :9443
  # Headscale listener would otherwise make Caddy bind both 10.0.0.1:80 and
  # [::]:80, which fails with EADDRINUSE on Linux.
  services.caddy.globalConfig = ''
    auto_https disable_redirects
    servers {
      metrics {
        per_host
      }
      trusted_proxies static 127.0.0.1/32 ::1/128
      client_ip_headers Cf-Connecting-Ip X-Forwarded-For
    }
  '';

  my.cloudflareDns = {
    enable = true;
    zone = publicDomain;
    records =
      mkDnsRecords [
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
        "hermes" # coding coordinator (pp-nas1)
        "openclaw" # agent gateway (pp-nas1)
        "dav" # radicale caldav/carddav (pp-nas1)
        "hass" # home assistant (pp-nas1)
        "home" # dashboard (pp-router1)
        "grafana" # observability dashboard
        "vault-admin" # vaultwarden admin panel (pp-router1)
        "gitea" # self-hosted git (pp-router1)
        "pages" # git-pages apex redirect (pp-router1)
        "*.pages" # git-pages wildcard static sites (pp-router1)
        "headplane" # headscale web UI (pp-router1)
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
        # Resend DKIM public key. Was created in Cloudflare but never
        # declared here; dns sync --prune would have deleted it and broken
        # outbound mail signing.
        {
          type = "TXT";
          name = "default._domainkey.${publicDomain}";
          content = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvnCJ3Oc30P1xR61+fsYkatoEMjENrhXyBCmb6rddMf/6ugdihRoEtZpveJtg/CNtgWx7DZOOMSMhY0vWSKlOXSvC+C8v7zZNIYLTtxMyWqnOu0MtMJvuO+YZVxR9ZmF4vzR3SAWbDw+NTza16Xt2LEjVO1sjlBdhLVPaLNkRRec/86pxsXiD+8BPIaBZV3TziCIHwEkH288xnUG6CB/vNZXBA9nV9NEG78rxXTx4fX6ZGa7VUu5IWxf1RGt6efbKUWMW9C5fJQVFn2lN+KuJI9nwePygSBI7T08tZs+B4KB3XHOXBFDJ9tf3Ah4jksrNxFilFoUjbC2Hd9VqT2NNFQIDAQAB";
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

    # --- Simple reverse proxies (router-local services) ---
    "${mkSub "home"}" = mkProxy "localhost:8082";
    "${mkSub "grafana"}" = mkProxy "localhost:3010";
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

    # git-pages static site hosting (LAN + Tailscale; DNS-01 wildcard cert).
    # Health path lets Blackbox verify DNS and CertExpiringSoon before sites exist.
    "*.${config.my.gitPages.domain}" = mkVhost ''
      @health path /.well-known/git-pages-health
      handle @health {
        respond "ok" 200
      }
      handle {
        reverse_proxy http://${config.my.gitPages.address}:${toString config.my.gitPages.port}
      }
      request_body {
        max_size ${config.my.gitPages.maxSiteSize}
      }
    '';
    "${config.my.gitPages.domain}" = mkVhost ''
      @health path /.well-known/git-pages-health
      handle @health {
        respond "ok" 200
      }
      handle {
        redir https://${config.my.gitea.admin.username}.${config.my.gitPages.domain}{uri} 302
      }
    '';

    # Headplane serves its UI under /admin only.
    "${config.my.headplane.domain}" = mkVhost ''
      redir / /admin 302
      reverse_proxy localhost:${toString config.my.headplane.port}
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
    "${mkSub "hermes"}" = mkNasProxy (mkSub "hermes") "";
    "${mkSub "openclaw"}" = mkNasProxy (mkSub "openclaw") "";
    "${mkSub "navidrome"}" = mkNasProxy (mkSub "navidrome") "";

    # --- Headscale control plane (public WAN :9443 via gray-cloud DDNS) ---
    # Unbound listenAddresses so WAN clients reach :9443 directly while all
    # :443 vhosts above remain strictly bound to LAN + Tailscale IPs.
    # Cloudflare Tunnel cannot carry Tailscale's TS2021 `Upgrade: tailscale-control-protocol`.
    "https://${config.my.headscale.domain}:${toString config.my.headscale.publicPort}" = {
      logFormat = mkPublicLogFormat "headscale";
      extraConfig = ''
        ${lib.optionalString caddyCrowdsecEnabled "crowdsec"}
        reverse_proxy 127.0.0.1:${toString config.my.headscale.listenPort} {
          flush_interval -1
        }
      '';
    };

    # --- Cloudflare Tunnel listeners (localhost only) ---
    # Personal site (public via tunnel)
    "http://:8224" = {
      listenAddresses = [ "127.0.0.1" ];
      logFormat = mkPublicLogFormat "site";
      extraConfig = ''
        ${lib.optionalString caddyCrowdsecEnabled "crowdsec"}
        root * ${pkgs.personal-site}
        file_server
      '';
    };

    # Vaultwarden (public via tunnel, blocks /admin)
    "http://:8223" = {
      listenAddresses = [ "127.0.0.1" ];
      logFormat = mkPublicLogFormat "vaultwarden";
      extraConfig = ''
        ${lib.optionalString caddyCrowdsecEnabled "crowdsec"}
        # Block /admin from public access (Cloudflare Tunnel)
        handle /admin* {
          respond "Forbidden" 403
        }
        handle {
          reverse_proxy localhost:${toString config.my.vaultwarden.port} {
            header_up X-Forwarded-For {client_ip}
          }
        }
      '';
    };
  };
}
