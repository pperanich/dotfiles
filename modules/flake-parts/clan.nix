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
        # wireguard = {
        #   module = {
        #     name = "wireguard";
        #     input = "clan-core";
        #   };
        #   roles = {
        #     controller = {
        #       machines.pp-nas1 = { };
        #       settings.endpoint = "vpn.prestonperanich.com";
        #     };
        #     peer.machines = {
        #       pp-ml1 = { };
        #       peranpl1-ml1 = { };
        #       peranpl1-ml2 = { };
        #     };
        #     peer.settings.controller = "pp-nas1";
        #   };
        # };
      };
    };
  };
}
