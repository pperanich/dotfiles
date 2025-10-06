# SOPS secrets management configuration
{ inputs, ... }:
let
  sopsFolder = ../../sops;
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
  flake.modules.nixos.sops =
    { pkgs, ... }:
    {
      # imports = [ inputs.sops-nix.nixosModules.sops ];
      inherit sops;
      environment.systemPackages = [ pkgs.sops ];

    };
  flake.modules.darwin.sops =
    { pkgs, ... }:
    {
      # imports = [ inputs.sops-nix.darwinModules.sops ];
      inherit sops;
      environment.systemPackages = [ pkgs.sops ];
    };
  flake.modules.homeManager.sops =
    { pkgs, config, ... }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];
      home.packages = [ pkgs.sops ];
      sops = {
        package = pkgs.sops-install-secrets.overrideAttrs (old: {
          env.GODEBUG = "x509negativeserial=1";
        });
        # This is the location of the host specific age-key and will to have been extracted to this location via hosts/shared/core/sops.nix on the host
        age = {
          keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
          sshKeyPaths = [
            "${config.home.homeDirectory}/.ssh/id_ed25519"
          ];
        };
        defaultSopsFile = "${sopsFolder}/secrets.yaml";
        validateSopsFiles = true;

        secrets = {
          "api_keys/opal_api_key" = { };
          "api_keys/openai_api_key" = { };
          "api_keys/assemblyai_api_key" = { };
          "api_keys/hugging_face_hub_token" = { };
          "api_keys/anthropic_api_key" = { };
          "api_keys/mistral_api_key" = { };
          "api_keys/openrouter_api_key" = { };
          "api_keys/gemini_api_key" = { };
          "private_keys/${config.home.username}" = {
            path = "${config.home.homeDirectory}/.ssh/id_ed25519";
            mode = "0400";
          };
        };
      };
    };
}
