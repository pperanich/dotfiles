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
        "pperanich-ml1" = {
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
        "pperanich-lm1" = {
          machineClass = "nixos";
          tags = [
            "mini"
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
              pperanich-ll1 = { };
              pperanich-lm1 = { };
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
        zerotier-home = {
          module = {
            name = "zerotier";
            input = "clan-core";
          };
          roles = {
            controller.machines.pperanich-lm1 = { };
            peer.machines = {
              pperanich-lm1 = { };
              pperanich-ml1 = { };
              peranpl1-ml1 = { };
              peranpl1-ml2 = { };
            };
          };
        };
        wireguard-home = {
          module = {
            name = "wireguard";
            input = "clan-core";
          };
          roles = {
            controller.machines.pperanich-lm1 = {
              settings.endpoint = "prestonperanich.com";
            };
            peer.machines = {
              pperanich-ml1 = { };
              peranpl1-ml1 = { };
              peranpl1-ml2 = { };
            };
          };
        };
      };
    };
  };
}
