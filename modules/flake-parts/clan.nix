{
  inputs,
  config,
  self,
  ...
}:
{
  imports = [
    inputs.clan-core.flakeModules.default
  ];

  flake.clan = {
    meta.name = "pperanich-clan";

    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;
    };

    secrets.age.plugins = [
      "age-plugin-yubikey"
      "age-plugin-fido2-hmac"
    ];

    inventory = {
      machines = {
        "pp-ml1" = {
          machineClass = "darwin";
          tags = [
            "laptop"
            "all"
          ];
        };
        "pp-nas1" = {
          machineClass = "nixos";
          tags = [
            "nas"
            "nixos"
            "all"
          ];
        };
        "pp-router1" = {
          machineClass = "nixos";
          tags = [
            "router"
            "nixos"
            "all"
          ];
        };
        "pp-rpi1" = {
          machineClass = "nixos";
          tags = [
            "rpi"
            "nixos"
            "all"
          ];
        };
        "pp-wsl1" = {
          machineClass = "nixos";
          tags = [
            "vm"
            "nixos"
            "all"
          ];
        };
      };

      instances = {
        clan-cache = {
          module = {
            name = "trusted-nix-caches";
            input = "clan-core";
          };
          roles.default.tags.all = { };
        };
        sshd-basic = {
          module = {
            name = "sshd";
            input = "clan-core";
          };
          roles = {
            server = {
              tags.all = { };
              settings = {
                authorizedKeys = self.lib.my.sshKeys;
                generateRootKey = true;
                certificate.searchDomains = [
                  "home.arpa"
                  "prestonperanich.com"
                  "pp-wg"
                ];
              };
            };
            client = {
              tags.all = { };
              settings = {
                certificate.searchDomains = [
                  "home.arpa"
                  "prestonperanich.com"
                  "pp-wg"
                ];
              };
            };
          };
        };
        users-root = {
          module = {
            name = "users";
            input = "clan-core";
          };
          roles.default = {
            tags.all = { };
            settings = {
              user = "root";
              share = true;
              prompt = false; # Set to true if you want to be prompted
              groups = [ ];
            };
          };
        };
        user-pperanich = {
          module = {
            name = "users";
            input = "clan-core";
          };
          roles.default = {
            tags.all = { };
            machines = {
              pp-ll1 = { };
              pp-nas1 = { };
              pp-rpi1 = { };
              pp-router1 = { };
            };
            settings = {
              user = "pperanich";
              share = true;
              prompt = true; # Set to true if you want to be prompted
              groups = [
                "admin"
                "wheel"
                "video"
                "audio"
                "dialout"
                "network"
                "wireshark"
                "i2c"
                "mysql"
                "docker"
                "podman"
                "git"
              ];
            };
            # extraModules = [ config.flake.modules.nixos.pperanich ];
          };
        };
        emergency-access = {
          module = {
            name = "emergency-access";
            input = "clan-core";
          };
          roles.default.tags.all = { };
        };
        pp-wg = {
          module = {
            name = "wireguard";
            input = "clan-core";
          };
          roles = {
            controller.machines.pp-router1 = {
              settings.endpoint = "vpn.prestonperanich.com";
            };
            peer.machines = {
              pp-nas1 = { };
              pp-wsl1 = { };
              pp-rpi1 = { };
              pp-ml1 = { };
            };
          };
        };

        # Dynamic DNS - keep DNS records updated with home IP
        # Records: vpn.prestonperanich.com, www.prestonperanich.com, prestonperanich.com
        dyndns = {
          module = {
            name = "dyndns";
            input = "clan-core";
          };
          roles.default.machines.pp-router1 = { };
          roles.default.settings = {
            period = 5; # Update every 5 minutes
            settings = {
              vpn-prestonperanich = {
                provider = "cloudflare";
                domain = "vpn.prestonperanich.com";
                secret_field_name = "token"; # Cloudflare API token
                extraSettings = {
                  ip_version = "ipv4";
                  ttl = 300; # 5 minutes (integer required by ddns-updater)
                  zone_identifier = "2604f1538bb4baa51662edac3bd91fc9";
                };
              };
              www-prestonperanich = {
                provider = "cloudflare";
                domain = "www.prestonperanich.com";
                secret_field_name = "token";
                extraSettings = {
                  ip_version = "ipv4";
                  ttl = 300;
                  zone_identifier = "2604f1538bb4baa51662edac3bd91fc9";
                };
              };
              root-prestonperanich = {
                provider = "cloudflare";
                domain = "prestonperanich.com";
                secret_field_name = "token";
                extraSettings = {
                  ip_version = "ipv4";
                  ttl = 300;
                  zone_identifier = "2604f1538bb4baa51662edac3bd91fc9";
                };
              };
            };
          };
        };

        # Borgbackup - pp-router1 as backup server for NixOS machines
        borgbackup = {
          module = {
            name = "borgbackup";
            input = "clan-core";
          };
          roles = {
            server.machines.pp-router1 = { };
            # Clients automatically backup to all servers in this instance
            client.machines = {
              pp-nas1 = { };
              # Add other NixOS machines as needed:
              # pp-ll1 = { };
            };
          };
        };

        # Syncthing - P2P file sync across machines
        syncthing = {
          module = {
            name = "syncthing";
            input = "clan-core";
          };
          roles.peer = {
            machines = {
              pp-router1 = { };
              pp-nas1 = { };
            };
            settings.folders = {
              documents = {
                path = "/home/pperanich/Sync/Documents";
              };
            };
          };
        };

      };
    };
  };
}
