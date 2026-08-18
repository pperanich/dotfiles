# Provider API keys, decrypted to ~/.config/sops-nix/secrets/api_keys/<name>.
#
# Split out of the homeManager `sops` module so that module stays pure wiring:
# every key declared there is a key the sops file must contain, and a profile
# that wants encrypted secrets without these tokens can leave this one out.
#
# Read by home/.zshrc, which exports the ones it finds as <NAME>_API_KEY. No
# Nix module consumes them, so adding a key here is a two-line change: this
# list, and the loop in .zshrc.
_: {
  flake.modules.homeManager.apiKeys = {
    sops.secrets = {
      "api_keys/openai_api_key" = { };
      "api_keys/hugging_face_hub_token" = { };
      "api_keys/anthropic_api_key" = { };
      "api_keys/openrouter_api_key" = { };
      "api_keys/gemini_api_key" = { };
      "api_keys/artificial_analysis_api_key" = { };
    };
  };
}
