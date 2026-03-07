# Web Hosting Setup (TODO)

> **Note:** This document is superseded by [Service Exposure Pathways](service-exposure.md)
> for the recommended approach to exposing services. The DDNS information below remains
> accurate for domains that require direct WAN IP resolution (e.g., WireGuard VPN endpoint).

Guide for hosting websites from pp-router1 using DDNS + reverse proxy.

## Current State

DDNS is configured and working. The following DNS records auto-update with your home IP every 5 minutes:

| Record                    | Status |
| ------------------------- | ------ |
| `prestonperanich.com`     | Active |
| `www.prestonperanich.com` | Active |
| `vpn.prestonperanich.com` | Active |

Configuration: `modules/flake-parts/clan.nix` (dyndns instance)

## Remaining Steps

### 1. Open Firewall Ports

Add WAN-accessible ports for HTTP/HTTPS in `modules/router/firewall.nix`:

```nix
# Example: Add to WAN input or create port forwarding
networking.firewall.allowedTCPPorts = [ 80 443 ];
```

Or use the existing firewall module's interface options if available.

### 2. Set Up Reverse Proxy

Choose one of:

#### Option A: nginx (traditional)

```nix
services.nginx = {
  enable = true;
  virtualHosts = {
    "prestonperanich.com" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        # Proxy to backend service or serve static files
        root = "/var/www/prestonperanich.com";
        # Or: proxyPass = "http://127.0.0.1:8080";
      };
    };
    "www.prestonperanich.com" = {
      enableACME = true;
      forceSSL = true;
      globalRedirect = "prestonperanich.com";  # Redirect www to apex
    };
  };
};
```

#### Option B: Caddy (simpler, automatic HTTPS)

```nix
services.caddy = {
  enable = true;
  virtualHosts = {
    "prestonperanich.com" = {
      extraConfig = ''
        root * /var/www/prestonperanich.com
        file_server
      '';
    };
    "www.prestonperanich.com" = {
      extraConfig = ''
        redir https://prestonperanich.com{uri} permanent
      '';
    };
  };
};
```

### 3. SSL Certificates (Let's Encrypt)

For nginx, enable ACME:

```nix
security.acme = {
  acceptTerms = true;
  defaults.email = "your-email@example.com";
};
```

Caddy handles this automatically.

### 4. Backend Services (Optional)

If hosting dynamic content, you might run:

- Static site generator output (Hugo, Zola, etc.)
- Self-hosted apps (Gitea, Nextcloud, etc.)
- Docker containers with reverse proxy

## Architecture

```
Internet
    |
    v
[Cloudflare DNS] --> prestonperanich.com -> <YOUR-PUBLIC-IP>
    |
    v
[Comcast Modem] (bridge mode)
    |
    v
[pp-router1] :80/:443
    |
    +---> nginx/caddy (reverse proxy + SSL termination)
           |
           +---> Static files (/var/www/...)
           +---> Backend services (localhost:8080, etc.)
           +---> Other machines on LAN (pp-nas1, etc.)
```

## Security Considerations

- Keep firewall rules minimal (only 80/443 from WAN)
- Use fail2ban for brute-force protection
- Consider Cloudflare proxy (orange cloud) for DDoS protection
- Regular security updates

## References

- [NixOS nginx module](https://nixos.wiki/wiki/Nginx)
- [NixOS Caddy module](https://nixos.wiki/wiki/Caddy)
- [ACME/Let's Encrypt on NixOS](https://nixos.wiki/wiki/ACME)
