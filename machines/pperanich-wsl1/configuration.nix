{
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-wsl.nixosModules.default

    # Core system configuration
    inputs.self.modules.nixos.base
    inputs.self.modules.homeManager.base

    # User setup
    inputs.self.modules.nixos.pperanich
    inputs.self.modules.homeManager.pperanich

    # Development environment (minimal for WSL)
    inputs.self.modules.homeManager.nvim
    inputs.self.modules.homeManager.zsh
    inputs.self.modules.nixos.rust
    inputs.self.modules.homeManager.rust

    # System utilities
    inputs.self.modules.nixos.fileExploration
    inputs.self.modules.homeManager.fileExploration
    inputs.self.modules.nixos.networkUtilities
    inputs.self.modules.homeManager.networkUtilities
  ];

  clan.core.networking.targetHost = lib.mkForce "root@pperanich-wsl1";
  clan.core.networking.buildHost = "root@pperanich-wsl1";

  nixpkgs.hostPlatform = "x86_64-linux";

  wsl = {
    enable = true;
    defaultUser = "pperanich";
    docker-desktop.enable = true;
    interop.register = true;
    startMenuLaunchers = true;
  };

  networking = {
    hostName = "pperanich-wsl1";
    interfaces.eth0 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
  };

  programs = {
    dconf.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    config.shared.default = "*";
  };

  services.openssh.ports = [ 2222 ];
}
