{ inputs, outputs, lib, config, pkgs, ... }:
{
  programs.git.enable = true;
  programs.git.extraConfig = {
    protocol.file = { allow = "always"; };
  };
  programs.git.lfs.enable = true;
  programs.git.includes = [
  {
    path = "~/dotfiles/config/git/oss.gitconfig";
    condition = "gitdir:~/Documents/repos/oss/";
  }
  {
    path = "~/dotfiles/config/git/work.gitconfig";
    condition = "gitdir:~/Documents/repos/work/";
  }
  ];
}
