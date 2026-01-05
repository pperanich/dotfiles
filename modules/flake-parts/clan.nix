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
      machines."pperanich-ml1".machineClass = "darwin";
      machines."pperanich-ml1".tags = [ "laptop" ];

      machines."peranpl1-ml1".machineClass = "darwin";
      machines."peranpl1-ml1".tags = [ "laptop" ];

      machines."peranpl1-ml2".machineClass = "darwin";
      machines."peranpl1-ml2".tags = [ "laptop" ];

      machines."pperanich-lm1".machineClass = "nixos";
      machines."pperanich-lm1".tags = [
        "mini"
        "nixos"
      ];

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
          roles.server.tags.all = { };
          roles.client.tags.all = { };
        };
        users-root = {
          module.name = "users";
          module.input = "clan-core";
          roles.default.tags.all = { };
          roles.default.settings = {
            user = "root";
            share = true;
            prompt = false; # Set to true if you want to be prompted
            groups = [ ];
          };
        };
        user-pperanich = {
          module = {
            name = "users";
            input = "clan-core";
          };
          roles.default.tags.all = { };
          roles.default.machines.pperanich-ll1 = { };
          roles.default.machines.pperanich-lm1 = { };
          roles.default.settings = {
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
          # roles.default.extraModules = [ config.flake.modules.nixos.pperanich ];
        };
        emergency-access = {
          module = {
            name = "emergency-access";
            input = "clan-core";
          };

          roles.default.tags.all = { };
        };
        # TODO: Re-enable after first deploy and run: clan vars generate --generator zerotier
        # zerotier-home = {
        #   module = {
        #     name = "zerotier";
        #     input = "clan-core";
        #   };
        #   roles.controller.machines.pperanich-lm1 = { };
        #   roles.peer.machines.pperanich-lm1 = { };
        #   roles.peer.machines.peranpl1-ml1 = { };
        #   roles.peer.machines.peranpl1-ml2 = { };
        # };
      };
    };
  };
}
