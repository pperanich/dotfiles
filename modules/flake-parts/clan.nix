{
  inputs,
  config,
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
        "peranpl1-ml1" = {
          machineClass = "darwin";
          tags = [
            "laptop"
            "all"
          ];
        };
        "peranpl1-ml2" = {
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
            server.tags.all = { };
            client.tags.all = { };
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
        # ZeroTier VPN - alternative to WireGuard (NixOS only, not supported on Darwin)
        # zerotier-home = {
        #   module = {
        #     name = "zerotier";
        #     input = "clan-core";
        #   };
        #   roles = {
        #     controller.machines.pp-router1 = { };
        #     peer.machines = {
        #       pp-nas1 = { };
        #       # Add other NixOS machines as needed:
        #       # pp-ll1 = { };
        #       # pp-ld1 = { };
        #     };
        #   };
        # };
        wireguard-home = {
          module = {
            name = "wireguard";
            input = "clan-core";
          };
          roles = {
            controller.machines.pp-router1 = {
              settings.endpoint = "vpn.prestonperanich.com";
            };
            peer.machines = {
              pp-ml1 = { };
              peranpl1-ml1 = { };
              peranpl1-ml2 = { };
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

        # Nix cache proxy - speeds up builds for all LAN machines
        # NOTE: Disabled - requires ncps nixpkgs module (not yet in stable nixpkgs)
        # ncps = {
        #   module = {
        #     name = "ncps";
        #     input = "clan-core";
        #   };
        #   roles = {
        #     server.machines.pp-router1 = {
        #       settings = {
        #         dataPath = "/var/lib/ncps";
        #         caches = [
        #           "https://cache.nixos.org"
        #           "https://nix-community.cachix.org"
        #         ];
        #         publicKeys = [
        #           "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        #           "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        #         ];
        #       };
        #     };
        #     client.tags.nixos = { };
        #   };
        # };

        # OpenClaw - AI assistant with Gateway/Node distributed architecture
        # Gateway runs on pp-router1, nodes on development machines
        # Token is automatically shared via clan.core.vars (share = true)
        # openclaw = {
        #   module = {
        #     name = "@pperanich/openclaw";
        #     input = "self"; # Local module from clanServices/openclaw
        #   };
        #   roles = {
        #     gateway.machines.pp-router1 = {
        #       settings = {
        #         port = 18789;
        #         endpoint = "vpn.prestonperanich.com";
        #       };
        #     };
        #     node.machines = {
        #       pp-wsl1 = {
        #         settings = {
        #           displayName = "WSL Dev Node";
        #           gatewayEndpoint = "vpn.prestonperanich.com:18789";
        #         };
        #       };
        #       pp-ml1 = {
        #         settings = {
        #           displayName = "MacBook Dev Node";
        #           gatewayEndpoint = "vpn.prestonperanich.com:18789";
        #         };
        #       };
        #     };
        #   };
        # };

      };
    };
  };
}
