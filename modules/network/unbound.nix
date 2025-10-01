{...}: {
  # NixOS system-level Unbound DNS resolver configuration
  flake.modules.nixos.unbound = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.unbound;
  in {
    options.features.unbound = {
      listenAddresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["127.0.0.1" "::1"];
        example = ["0.0.0.0" "::0"];
        description = "Addresses to listen on";
      };
      allowedClients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["127.0.0.0/8" "::1/128"];
        example = ["192.168.1.0/24"];
        description = "Client networks allowed to query";
      };
      forwardZones = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {};
        example = {
          "local" = ["192.168.1.1"];
          "home.arpa" = ["192.168.1.1"];
        };
        description = "DNS zones to forward to specific servers";
      };
      enableAdBlocking = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable ad-blocking via blocklists";
      };
    };

    config = {
      # Unbound service
      services.unbound = {
        enable = true;

        settings = {
          server = {
            # Network configuration
            interface = cfg.listenAddresses;
            access-control = map (client: "${client} allow") cfg.allowedClients;

            # Performance settings
            num-threads = 4;
            msg-cache-slabs = 8;
            rrset-cache-slabs = 8;
            infra-cache-slabs = 8;
            key-cache-slabs = 8;

            # Cache settings
            cache-min-ttl = 300;
            cache-max-ttl = 86400;

            # Security settings
            hide-identity = true;
            hide-version = true;
            harden-glue = true;
            harden-dnssec-stripped = true;
            use-caps-for-id = true;

            # Privacy settings
            qname-minimisation = true;
            aggressive-nsec = true;

            # Performance optimizations
            so-rcvbuf = "1m";
            so-sndbuf = "1m";

            # Local zones
            private-address = [
              "192.168.0.0/16"
              "169.254.0.0/16"
              "172.16.0.0/12"
              "10.0.0.0/8"
              "fd00::/8"
              "fe80::/10"
            ];
          };

          # Forward zones
          forward-zone =
            lib.mapAttrsToList (zone: servers: {
              name = zone;
              forward-addr = servers;
            })
            cfg.forwardZones;

          # Root hints
          root-hints = "${pkgs.dns-root-data}/root.hints";
        };
      };

      # Ad-blocking configuration
      systemd.services.unbound-adblock = lib.mkIf cfg.enableAdBlocking {
        description = "Update Unbound ad-blocking lists";
        serviceConfig = {
          Type = "oneshot";
          User = "unbound";
          Group = "unbound";
        };
        script = ''
          # Download and process blocklists
          blocklist_dir="/var/lib/unbound/blocklists"
          mkdir -p "$blocklist_dir"

          # Download popular blocklists
          ${pkgs.curl}/bin/curl -s "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" \
            | ${pkgs.gawk}/bin/awk '/^0\.0\.0\.0/ {print "local-zone: \"" $2 "\" static"}' \
            > "$blocklist_dir/adblock.conf"

          # Signal unbound to reload
          ${pkgs.systemd}/bin/systemctl reload unbound
        '';
        path = with pkgs; [curl gawk systemd];
      };

      # Timer for ad-blocking updates
      systemd.timers.unbound-adblock = lib.mkIf cfg.enableAdBlocking {
        description = "Update Unbound ad-blocking lists daily";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };

      # Include blocklist in config
      services.unbound.settings.include = lib.mkIf cfg.enableAdBlocking [
        "/var/lib/unbound/blocklists/*.conf"
      ];

      # Firewall
      networking.firewall.allowedTCPPorts = lib.mkIf (builtins.any (addr: addr != "127.0.0.1" && addr != "::1") cfg.listenAddresses) [53];
      networking.firewall.allowedUDPPorts = lib.mkIf (builtins.any (addr: addr != "127.0.0.1" && addr != "::1") cfg.listenAddresses) [53];

      # Use Unbound as system resolver
      networking.nameservers = ["127.0.0.1" "::1"];
      networking.resolvconf.useLocalResolver = true;
    };
  };

  # Home Manager DNS tools
  flake.modules.homeManager.unbound = {pkgs, ...}: {
    home.packages = with pkgs; [
      dig
      host
      nslookup
      dnsutils
    ];
  };
}
