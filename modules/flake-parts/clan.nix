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
        # zerotier-home = {
        #   module = {
        #     name = "zerotier";
        #     input = "clan-core";
        #   };
        #   roles = {
        #     controller.machines.pp-nas1 = { };
        #     peer.machines = {
        #       pp-nas1 = { };
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

        # Dynamic DNS - keep vpn.prestonperanich.com updated with home IP
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
                domain = "prestonperanich.com";
                secret_field_name = "token"; # Cloudflare API token
                extraSettings = {
                  host = "vpn"; # vpn.prestonperanich.com
                  ip_version = "ipv4";
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
      };
    };
  };
}
