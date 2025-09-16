# NixOS nginx development server configuration
# Provides nginx-based reverse proxy and development virtual hosts
# Only available on NixOS systems
_: {
  # NixOS system configuration for nginx development server
  flake.modules.nixos.webDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.webDev;
  in {
    options.features.webDev = {
      webServer = lib.mkOption {
        type = lib.types.enum ["nginx" "apache" "caddy"];
        default = "nginx";
        description = "System web server to configure for development";
      };

      devDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["localhost.dev" "app.test" "api.test"];
        description = "Development domains to configure with SSL certificates";
      };
    };

    config = {
      # Configure the selected web server
      services = lib.mkMerge [
        (lib.mkIf (cfg.webServer == "nginx") {
          nginx = {
            enable = true;
            recommendedTlsSettings = true;
            recommendedOptimisation = true;
            recommendedGzipSettings = true;
            recommendedProxySettings = true;

            # Development virtual hosts
            virtualHosts = lib.listToAttrs (map (domain: {
                name = domain;
                value = {
                  listen = [
                    {
                      addr = "127.0.0.1";
                      port = 80;
                    }
                    {
                      addr = "127.0.0.1";
                      port = 443;
                      ssl = true;
                    }
                  ];
                  serverName = domain;
                  root = "/var/www/${domain}";

                  locations."/" = {
                    tryFiles = "$uri $uri/ =404";
                  };

                  # Proxy common development ports
                  locations."/api/" = {
                    proxyPass = "http://127.0.0.1:3000/";
                    proxyWebsockets = true;
                  };

                  locations."/ws" = {
                    proxyPass = "http://127.0.0.1:3001";
                    proxyWebsockets = true;
                  };
                };
              })
              cfg.devDomains);
          };
        })

        (lib.mkIf (cfg.webServer == "caddy") {
          caddy = {
            enable = true;
            virtualHosts = lib.listToAttrs (map (domain: {
                name = domain;
                value = {
                  hostName = domain;
                  extraConfig = ''
                    root * /var/www/${domain}
                    file_server

                    # Reverse proxy for API
                    handle_path /api/* {
                      reverse_proxy 127.0.0.1:3000
                    }

                    # WebSocket support
                    handle /ws {
                      reverse_proxy 127.0.0.1:3001
                    }
                  '';
                };
              })
              cfg.devDomains);
          };
        })
      ];

      # System packages for selected web server
      environment.systemPackages = with pkgs; [
        # System web server tools
        (
          if cfg.webServer == "nginx"
          then nginx
          else if cfg.webServer == "caddy"
          then caddy
          else httpd
        )
      ];

      # Firewall configuration for development
      networking.firewall = {
        allowedTCPPorts = [80 443 3000 3001 4000 5000 8000 8080 8443];
        allowedUDPPorts = [53]; # DNS for local development
      };

      # Create development web directories
      systemd.tmpfiles.rules =
        map (
          domain: "d /var/www/${domain} 0755 nginx nginx -"
        )
        cfg.devDomains;

      # DNS resolution for development domains
      networking.hosts = lib.listToAttrs (map (domain: {
          name = "127.0.0.1";
          value = [domain];
        })
        cfg.devDomains);

      # Configure system services for web development
      launchd.user.agents = {
        # Optional: Auto-start development services
        nginx-dev = lib.mkIf false {
          # Disabled by default
          serviceConfig = {
            ProgramArguments = [
              "${pkgs.nginx}/bin/nginx"
              "-g"
              "daemon off;"
            ];
            RunAtLoad = false;
            KeepAlive = false;
          };
        };
      };
    };
  };
}
