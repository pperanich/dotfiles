{
  inputs,
  config,
  lib,
  ...
}:
let
  sopsFolder = builtins.toString lib.custom.relativeToRoot "sops/";
  homeDirectory = config.home.homeDirectory;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  sops = {
    # This is the location of the host specific age-key and will to have been extracted to this location via hosts/common/core/sops.nix on the host
    age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = "${sopsFolder}/secrets.yaml";
    validateSopsFiles = false;

    secrets = {
        "api_keys" = {
            "opal_api_key" = {};
            "openai_api_key" = {};
            "assemblyai_api_key" = {};
            "hugging_face_hub_token" = {};
            "anthropic_api_key" = {};
            "mistral_api_key" = {};
        };
    };
  };
}