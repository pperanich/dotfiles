# The inventory: which machines exist, and which clan services they run.
# Usually the only file in this repo you edit regularly.
{
  inputs,
  ...
}:
{
  imports = [
    inputs.clan-core.flakeModules.default
  ];

  flake.clan = {
    meta.name = "my-private-clan";

    # Machine files receive the upstream's modules and lib, so a machine here
    # is written exactly like one in the public repo.
    specialArgs = {
      inherit (inputs.upstream) inputs lib modules;
      outputs = inputs.upstream;
    };

    inventory = {
      machines = {
        secret-host = {
          machineClass = "nixos";
          tags = [ "all" ];
        };
      };

      # Service instances are per-inventory: a machine here cannot join the
      # upstream clan's wireguard, borgbackup or syncthing instances.
      instances = {
        sshd = {
          module = {
            name = "sshd";
            input = "clan-core";
          };
          roles.server.tags.all = { };
          roles.client.tags.all = { };
        };
        root-user = {
          module = {
            name = "users";
            input = "clan-core";
          };
          roles.default = {
            tags.all = { };
            settings = {
              user = "root";
              share = true;
              prompt = false;
            };
          };
        };
      };
    };
  };
}
