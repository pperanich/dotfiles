{
  config,
  lib,
  pkgs,
  hostSpec,
  inputs,
  outputs,
  ...
}:
let
  homePrefix = if pkgs.stdenv.hostPlatform.isDarwin then "Users" else "home";
in
{
  imports = [
    ./sops.nix
    inputs.nix-index-database.hmModules.nix-index
  ];

  home = {
    homeDirectory = "/${homePrefix}/${config.home.username}";
    sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    sessionVariables = {
      OPAL_API_KEY = "REDACTED_OPAL_API_KEY_XXX";
      OPENAI_API_KEY = "sk-REDACTED_OPENAI_API_KEY_XXX";
      ASSEMBLYAI_API_KEY = "REDACTED_ASSEMBLYAI_KEY_XXX";
      HUGGING_FACE_HUB_TOKEN = "hf_REDACTED_HUGGINGFACE_TOKEN_XXX";
      ANTHROPIC_API_KEY = "sk-ant-REDACTED_ANTHROPIC_API_KEY_XXX";
      MISTRAL_API_KEY = "REDACTED_MISTRAL_API_KEY_XXX";
      FLAKE = "${config.home.homeDirectory}/dotfiles/";
    };
    stateVersion = "24.11";
  };

  lib.meta = {
    configPath = "${config.home.homeDirectory}/dotfiles/home/";
    mkMutableSymlink =
      path: config.lib.file.mkOutOfStoreSymlink (config.lib.meta.configPath + path);
  };

  xdg.enable = true;

  programs = {
    # home-manager.enable = true;
    pandoc.enable = true;
    gpg.enable = true;
    dircolors.enable = true;
    direnv.enable = true;
    atuin.enable = true;
    zoxide.enable = true;
    nix-index-database.comma.enable = true;
  };

  services.ssh-agent.enable = true;

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
      packageOverrides = _: {
        nixcasks = import inputs.nixcasks {
          inherit pkgs;
          osVersion = "sonoma";
        };
      };
    };
  };

  programs.home-manager.enable = true;
}