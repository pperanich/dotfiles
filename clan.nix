{}:
{
  meta.name = "pperanich-clan";

  inventory = {
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
}
