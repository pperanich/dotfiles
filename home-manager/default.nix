{ inputs, outputs, lib, config, pkgs, ... }:
{
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

  lib.meta = {
    configPath = "${config.home.homeDirectory}/dotfiles/home/";
    mkMutableSymlink =
      path: config.lib.file.mkOutOfStoreSymlink (config.lib.meta.configPath + path);
  };

  xdg.enable = true;
  home = {
    sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    sessionVariables = {
      OPAL_API_KEY = "REDACTED_OPAL_API_KEY_XXX";
      OPENAI_API_KEY = "sk-REDACTED_OPENAI_API_KEY_XXX";
      ASSEMBLYAI_API_KEY = "REDACTED_ASSEMBLYAI_KEY_XXX";
      HUGGING_FACE_HUB_TOKEN = "hf_REDACTED_HUGGINGFACE_TOKEN_XXX";
      ANTHROPIC_API_KEY = "sk-ant-REDACTED_ANTHROPIC_API_KEY_XXX";
      FLAKE = "${config.home.homeDirectory}/dotfiles/";
    };
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.11";
  };

  programs = {
    home-manager.enable = true;
    pandoc.enable = true;
    gpg.enable = true;
    dircolors.enable = true;
    direnv.enable = true;
    atuin.enable = true;
    zoxide.enable = true;
  };

  imports = [
    ./features/cli.nix
    ./features/nvim.nix
    ./features/git.nix
    ./features/zsh.nix
    ./features/nushell.nix
    ./features/ssh.nix
    ./features/podman.nix
    inputs.nix-index-database.hmModules.nix-index
    { programs.nix-index-database.comma.enable = true; }
    # <sops-nix/modules/home-manager/sops.nix>
  ] ++ (builtins.attrValues outputs.homeManagerModules);

}
