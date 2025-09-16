{inputs, ...}: {
  imports = [
    inputs.clan-core.flakeModules.default
  ];

  flake.clan = {
    meta.name = "pperanich-clan";

    inventory = {
      machines."peranpl1-ml1".machineClass = "darwin";
      machines."peranpl1-ml1".tags = ["laptop"];

      machines."peranpl1-ml2".machineClass = "darwin";
      machines."peranpl1-ml2".tags = ["laptop"];

      instances = {
        clan-cache = {
          module = {
            name = "trusted-nix-caches";
            input = "clan-core";
          };
          roles.default.tags.nixos = {};
        };
        sshd-basic = {
          module = {
            name = "sshd";
            input = "clan-core";
          };
          roles.server.tags.nixos = {};
          roles.client.tags.nixos = {};
        };
        user-pperanich = {
          module = {
            name = "users";
            input = "clan-core";
          };
          roles.default.tags.nixos = {};
          roles.default.settings = {
            user = "pperanich";
            prompt = true;
          };
        };
        admin = {
          roles.default.tags.nixos = {};
          roles.default.settings = {};
        };
        emergency-access = {
          module = {
            name = "emergency-access";
            input = "clan-core";
          };

          roles.default.tags.nixos = {};
        };
      };
    };
  };
}
