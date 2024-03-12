{ inputs, outputs, lib, config, pkgs, ... }:
{
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  programs.home-manager.enable = true;
  xdg.enable = true;
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  home.sessionVariables = {
    OPAL_API_KEY = "REDACTED_OPAL_API_KEY_XXX";
    OPENAI_API_KEY = "sk-REDACTED_OPENAI_API_KEY_XXX";
    ASSEMBLYAI_API_KEY = "REDACTED_ASSEMBLYAI_KEY_XXX";
    HUGGING_FACE_HUB_TOKEN = "hf_REDACTED_HUGGINGFACE_TOKEN_XXX";
    ANTHROPIC_API_KEY = "sk-ant-REDACTED_ANTHROPIC_API_KEY_XXX";
  };

  programs.pandoc.enable = true;
  programs.gpg.enable = true;
  programs.dircolors.enable = true;
  programs.direnv.enable = true;
  programs.atuin.enable = true;
  programs.zoxide.enable = true;

  imports = [
    ./features/cli.nix
    ./features/nvim.nix
    ./features/git.nix
    ./features/zsh.nix
    ./features/nushell.nix
    ./features/ssh.nix
    ./features/podman.nix
    # <sops-nix/modules/home-manager/sops.nix>
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
