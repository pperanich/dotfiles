{ inputs, lib, pkgs, config, outputs, ... }:
{
  imports = [
    ../features/cli.nix
    ../features/nvim.nix
  ] ++ (builtins.attrValues outputs.homeManagerModules);
}
