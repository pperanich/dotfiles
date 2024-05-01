{ inputs, outputs, lib, config, pkgs, ... }:
{
  # programs.git = {
  #   enable = true;
  #   extraConfig = {
  #     protocol.file = { allow = "always"; };
  #   };
  #   lfs.enable = true;
  #   includes = [
  #   {
  #     path = "~/dotfiles/config/git/oss.gitconfig";
  #     condition = "gitdir:~/Documents/repos/oss/";
  #   }
  #   {
  #     path = "~/dotfiles/config/git/work.gitconfig";
  #     condition = "gitdir:~/Documents/repos/work/";
  #   }
  #   ];
  # };
}
