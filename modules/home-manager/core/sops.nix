# SOPS secrets management for home-manager
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home;
  sopsFolder = lib.my.relativeToRoot "sops/";
  inherit (config.home) homeDirectory;
in {
  imports = [inputs.sops-nix.homeManagerModules.sops];

  config = lib.mkIf cfg.enable {
    sops = {
      # This is the location of the host specific age-key and will to have been extracted to this location via hosts/shared/core/sops.nix on the host
      age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";
      defaultSopsFile = "${sopsFolder}/secrets.yaml";
      validateSopsFiles = true;

      secrets = {
        "api_keys/opal_api_key" = {};
        "api_keys/openai_api_key" = {};
        "api_keys/assemblyai_api_key" = {};
        "api_keys/hugging_face_hub_token" = {};
        "api_keys/anthropic_api_key" = {};
        "api_keys/mistral_api_key" = {};
      };
    };
  };
}
