{ pkgs, inputs, outputs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../common/global
    ../common/users/pperanich
    ../common/features/wsl.nix
    {
      home-manager.extraSpecialArgs = { inherit inputs outputs; };
      home-manager.useUserPackages = true;
      home-manager.users.pperanich = {
        imports = [
          ../../home-manager
          ../../home-manager/features/emacs.nix
          ../../home-manager/features/desktop.nix
          ../../home-manager/features/tex.nix
          ../../home-manager/features/vscode.nix
        ];
      };
    }
  ];

  networking = {
    hostName = "pperanich-wsl1";
    useDHCP = true;
    interfaces.eth0 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_zen;
    binfmt.emulatedSystems = [ "aarch64-linux" "i686-linux" ];
  };

  programs = {
    dconf.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  system.stateVersion = "23.05";
}
