# SOPS secrets management configuration
{ inputs, ... }:
let
  sopsFolder = ../../sops;
  # Base sops config shared between NixOS and Darwin
  # Note: age.plugins is added per-platform below since it needs pkgs
  #
  # Priority 900 throughout, not mkDefault: clan-core defines
  # sops.defaultSopsFile at mkDefault (1000), so an equal-priority default here
  # is a conflict. 900 beats clan's default while still losing to a plain
  # assignment, which is what lets a machine defined in another flake repoint
  # these at its own secrets. See docs/private-machines.md.
  sopsCommon =
    lib:
    let
      overridable = lib.mkOverride 900;
    in
    {
      defaultSopsFile = overridable "${sopsFolder}/secrets.yaml";
      # Runs sops-install-secrets -check-mode=sopsfile in the manifest's build
      # phase: every declared secret must name a key that exists in the file.
      # Key names are plaintext in a sops file, so nothing is decrypted. Missing
      # keys fail the build instead of failing partway through activation.
      validateSopsFiles = overridable true;
      age = {
        # Use clan-managed age key for decryption
        keyFile = overridable "/var/lib/sops-nix/key.txt";
        # Also import host SSH keys as age keys
        sshKeyPaths = [
          # "/etc/ssh/ssh_host_ed25519_key"
          # "/run/secrets/vars/openssh/ssh.id_ed25519"
        ];
      };
      # secrets will be output to /run/secrets
      # e.g. /run/secrets/msmtp-password
      # secrets required for user creation are handled in respective ./users/<username>.nix files
      # because they will be output to /run/secrets-for-users and only when the user is assigned to a host.
    };
in
{
  flake.modules = {
    nixos.sops =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        # clan-core imports this too; the module system dedupes by path and
        # clan-core.inputs.sops-nix follows ours, so both resolve to the same
        # module. Importing it here keeps this module usable from a flake that
        # doesn't go through clan.
        imports = [ inputs.sops-nix.nixosModules.sops ];
        sops = lib.mkMerge [
          (sopsCommon lib)
          {
            package = pkgs.sops-install-secrets;
            # YubiKey support for system-level secrets
            age.plugins = [ pkgs.age-plugin-yubikey ];
          }
          # WiFi passphrase secret for hostapd AP mode or wpa_supplicant client mode
          (lib.mkIf
            ((config.my.router.hostapd.enable or false) || (config.networking.wireless.enable or false))
            {
              secrets.wifi_passphrase = {
                sopsFile = "${sopsFolder}/secrets.yaml";
                mode = "0400";
              };
            }
          )
          # Additional WiFi passphrases for network segmentation (IoT, Guest SSIDs)
          (lib.mkIf (config.my.router.networks.enable or false) {
            secrets.wifi_passphrase_iot = {
              sopsFile = "${sopsFolder}/secrets.yaml";
              mode = "0400";
            };
            secrets.wifi_passphrase_guest = {
              sopsFile = "${sopsFolder}/secrets.yaml";
              mode = "0400";
            };
          })
        ];
        environment.systemPackages = [ pkgs.sops ];
      };
    darwin.sops =
      { pkgs, lib, ... }:
      {
        imports = [ inputs.sops-nix.darwinModules.sops ];
        sops = lib.mkMerge [
          (sopsCommon lib)
          {
            package = pkgs.sops-install-secrets;
            # YubiKey support for system-level secrets
            age.plugins = [ pkgs.age-plugin-yubikey ];

            # Fix PATH for sops-install-secrets on Darwin
            # hdiutil is needed to create RAM disk for secrets but isn't in default PATH
            environment.PATH = lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";
          }
        ];
        environment.systemPackages = [ pkgs.sops ];
      };
    homeManager.sops =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        imports = [ inputs.sops-nix.homeManagerModules.sops ];
        home.packages = [ pkgs.sops ];

        # TODO: Remove after sops-nix PR is merged that fixes empty PATH on Darwin
        # https://github.com/Mic92/sops-nix/issues/899 (age plugin support regression)
        # The home-manager module sets PATH = lib.makeBinPath cfg.age.plugins, which
        # results in empty PATH when no plugins are configured, breaking LaunchAgent.
        # We include age-plugin-yubikey in the PATH for YubiKey decryption support.
        launchd.agents.sops-nix = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
          enable = true;
          config = {
            EnvironmentVariables = {
              PATH = pkgs.lib.mkForce "${
                pkgs.lib.makeBinPath [ pkgs.age-plugin-yubikey ]
              }:/usr/bin:/bin:/usr/sbin:/sbin";
            };
          };
        };

        sops = {
          package = pkgs.sops-install-secrets;
          age = {
            # Use SSH key for decryption (converted to age key automatically by sops-nix)
            # The SSH private key is deployed via system-level sops BEFORE home-manager runs
            # secrets.yaml is encrypted for the SSH-derived age key (e.g., &pperanich)
            sshKeyPaths = [
              "${config.home.homeDirectory}/.ssh/id_ed25519"
              "/etc/ssh/ssh_host_ed25519_key"
            ];
            # YubiKey support - if plugged in, can be used for decryption
            # Secrets have both YubiKey AND machine/SSH keys as recipients,
            # so system boots fine without YubiKey (SSH key decrypts)
            plugins = [ pkgs.age-plugin-yubikey ];
          };
          # mkDefault so a profile in another flake can point these at its own
          # secrets file with a plain assignment. Nothing else defines them, so
          # unlike the system side this needs no priority juggling.
          defaultSopsFile = lib.mkDefault "${sopsFolder}/secrets.yaml";
          validateSopsFiles = lib.mkDefault true;
          # SSH private key is deployed via system-level sops in user modules
          # (modules/users/*.nix) BEFORE home-manager runs, breaking the
          # chicken-and-egg problem where home-manager sops needs the SSH key
          # to decrypt, but the SSH key is itself a secret.
          #
          # No secrets are declared here on purpose: every declared key must
          # exist in the sops file, so this module stays importable by a
          # profile that keeps a different set. The provider tokens live in
          # modules/shell/api-keys.nix (homeManager.apiKeys).
        };
      };
  };
}
