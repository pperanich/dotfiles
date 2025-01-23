# This file (and the global directory) holds config that i use on all hosts
{ inputs, outputs, lib, config, pkgs, system, ... }: 
let
  platform = if builtins.match ".*-darwin" system != null then "darwin" else "nixos";
  platformModules = "${platform}Modules";
in
{
  imports = lib.flatten [
    inputs.home-manager.${platformModules}.home-manager
    inputs.sops-nix.${platformModules}.sops
    ./sops.nix
    ./ssh.nix
    ./nix.nix
    "./${platform}.nix"
    (map lib.custom.relativeToRoot [
      "modules/common"
      "modules/${platform}"
    ])
  ];

  home-manager.extraSpecialArgs = { inherit inputs outputs; };

  environment.enableAllTerminfo = true;
}
