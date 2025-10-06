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
      machines."peranpl1-ml1".machineClass = "darwin";
      machines."peranpl1-ml1".tags = [ "laptop" ];

      machines."peranpl1-ml2".machineClass = "darwin";
      machines."peranpl1-ml2".tags = [ "laptop" ];

      instances = {
        clan-cache = {
          module = {
            name = "trusted-nix-caches";
            input = "clan-core";
          };
          roles.default.tags.nixos = { };
        };
        sshd-basic = {
          module = {
            name = "sshd";
            input = "clan-core";
          };
          roles.server.tags.nixos = { };
          roles.client.tags.nixos = { };
        };
        users-root = {
          module.name = "users";
          module.input = "clan-core";
          roles.default.tags.nixos = { };
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
          roles.default.tags.nixos = { };
          roles.default.settings = {
            user = "pperanich";
            share = true;
            prompt = true; # Set to true if you want to be prompted
            groups = [
              "admin"
            ];
          };
          # roles.default.extraModules = [ config.flake.modules.nixos.pperanich ];
        };
        emergency-access = {
          module = {
            name = "emergency-access";
            input = "clan-core";
          };

          roles.default.tags.nixos = { };
        };
      };
    };
  };
}
