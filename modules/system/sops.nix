# SOPS secrets management configuration
{ inputs, ... }:
let
  sopsFolder = ../../sops;
  # Base sops config shared between NixOS and Darwin
  # Note: age.plugins is added per-platform below since it needs pkgs
  sops = {
    defaultSopsFile = "${sopsFolder}/secrets.yaml";
    validateSopsFiles = false;
    age = {
      # automatically import host SSH keys as age keys
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
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
        # imports = [ inputs.sops-nix.nixosModules.sops ];
        sops = lib.mkMerge [
          sops
          {
            # YubiKey support for system-level secrets
            age.plugins = [ pkgs.age-plugin-yubikey ];
          }
          # WiFi passphrase secret for hostapd AP mode or wpa_supplicant client mode
          (lib.mkIf
            ((config.features.router.hostapd.enable or false) || (config.networking.wireless.enable or false))
            {
              secrets.wifi_passphrase = {
                sopsFile = "${sopsFolder}/secrets.yaml";
                mode = "0400";
              };
            }
          )
          # Additional WiFi passphrases for network segmentation (IoT, Guest SSIDs)
          (lib.mkIf (config.features.router.networks.enable or false) {
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
        # imports = [ inputs.sops-nix.darwinModules.sops ];
        sops = lib.mkMerge [
          sops
          {
            # YubiKey support for system-level secrets
            age.plugins = [ pkgs.age-plugin-yubikey ];

            # Fix PATH for sops-install-secrets on Darwin
            # hdiutil is needed to create RAM disk for secrets but isn't in default PATH
            # environment.PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
          }
        ];
        environment.systemPackages = [ pkgs.sops ];
      };
    homeManager.sops =
      { pkgs, config, ... }:
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
          age = {
            # Use SSH key for decryption (converted to age key automatically by sops-nix)
            # The SSH private key is deployed via system-level sops BEFORE home-manager runs
            # secrets.yaml is encrypted for the SSH-derived age key (e.g., &pperanich)
            sshKeyPaths = [
              "${config.home.homeDirectory}/.ssh/id_ed25519"
            ];
            # YubiKey support - if plugged in, can be used for decryption
            # Secrets have both YubiKey AND machine/SSH keys as recipients,
            # so system boots fine without YubiKey (SSH key decrypts)
            plugins = [ pkgs.age-plugin-yubikey ];
          };
          defaultSopsFile = "${sopsFolder}/secrets.yaml";
          validateSopsFiles = true;
          # SSH private key is deployed via system-level sops in user modules
          # (modules/users/*.nix) BEFORE home-manager runs, breaking the
          # chicken-and-egg problem where home-manager sops needs the SSH key
          # to decrypt, but the SSH key is itself a secret.
          secrets = {
            "api_keys/opal_api_key" = { };
            "api_keys/openai_enterprise_api_key" = { };
            "api_keys/openai_api_key" = { };
            "api_keys/opencode_api_key" = { };
            "api_keys/assemblyai_api_key" = { };
            "api_keys/hugging_face_hub_token" = { };
            "api_keys/anthropic_api_key" = { };
            "api_keys/mistral_api_key" = { };
            "api_keys/openrouter_api_key" = { };
            "api_keys/gemini_api_key" = { };
            "api_keys/artificial_analysis_api_key" = { };
          };
        };
      };
  };
}
