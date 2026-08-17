# Copy to modules/flake-parts/clan.nix — see README.md in this directory.
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
    meta.name = "my-clan";

    # Same specialArgs systems.nix passed, so machine files don't change
    specialArgs = {
      inherit inputs;
      inherit (config.flake) modules lib;
      outputs = config.flake;
    };

    inventory = {
      machines = {
        example-nixos = {
          machineClass = "nixos";
          tags = [ "all" ];
        };
        example-darwin = {
          machineClass = "darwin";
          tags = [ "all" ];
        };
      };

      # Clan services, applied by tag. Each one generates and deploys its own
      # secrets via `clan vars`, independent of the sops/secrets.yaml file.
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
