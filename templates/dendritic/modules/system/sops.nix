# sops-nix wiring for all three platforms.
#
# Decryption keys, in the order they matter:
#   - NixOS/Darwin: the host's SSH key (/etc/ssh/ssh_host_ed25519_key), converted
#     to an age key by sops-nix at activation. Add each host's age key to
#     sops/.sops.yaml with `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`.
#   - home-manager: the user's ~/.ssh/id_ed25519. On NixOS/Darwin that private
#     key is itself deployed by the system-level sops in modules/users/example.nix,
#     which runs before home-manager — that's what breaks the chicken-and-egg.
#   - You, editing secrets: `nix develop` exports SOPS_AGE_KEY from your SSH key.
#
# Secrets land in /run/secrets/<name> (system) and
# ~/.config/sops-nix/secrets/<name> (home-manager). Reference them by path;
# never inline a secret value into the Nix store.
{ inputs, ... }:
let
  sopsFolder = ../../sops;

  common = {
    defaultSopsFile = "${sopsFolder}/secrets.yaml";
    # Set to true once secrets.yaml is actually encrypted
    validateSopsFiles = false;
  };
in
{
  flake.modules = {
    nixos.sops =
      { pkgs, ... }:
      {
        imports = [ inputs.sops-nix.nixosModules.sops ];

        sops = common // {
          age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        };

        environment.systemPackages = [ pkgs.sops ];
      };

    darwin.sops =
      { lib, pkgs, ... }:
      {
        imports = [ inputs.sops-nix.darwinModules.sops ];

        sops = common // {
          age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          # sops-install-secrets shells out to hdiutil for the secrets RAM disk,
          # which isn't on the default launchd PATH
          environment.PATH = lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";
        };

        environment.systemPackages = [ pkgs.sops ];
      };

    homeManager.sops =
      { config, pkgs, ... }:
      {
        imports = [ inputs.sops-nix.homeManagerModules.sops ];

        sops = common // {
          age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

          # Each entry decrypts sops/secrets.yaml -> a file on disk.
          # `api_keys/openai` here means the nested `api_keys: openai:` key.
          secrets = {
            # "api_keys/openai" = { };
          };
        };

        home.packages = [ pkgs.sops ];
      };
  };
}
