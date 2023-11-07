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

  programs.pandoc.enable = true;
  programs.gpg.enable = true;

  imports = [
    ./features/cli.nix
    ./features/nvim.nix
    ./features/git.nix
    ./features/zsh.nix
    ./features/ssh.nix
    ./features/podman.nix
    # <sops-nix/modules/home-manager/sops.nix>
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
