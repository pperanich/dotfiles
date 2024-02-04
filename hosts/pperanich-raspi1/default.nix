{ inputs, outputs, lib, config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../common/global
    ../common/users/pperanich
    ../common/features/ssh.nix
    {
      home-manager.extraSpecialArgs = { inherit inputs outputs; };
      home-manager.useUserPackages = true;
      home-manager.users.pperanich = {
        imports = [
          ../../home-manager
        ];
      };
    }
  ];

  sdImage.compressImage = false;

  networking = {
    hostName = "pperanich-raspi1";
    useDHCP = true;
    # networks."VirusInfectedWifi".psk = "vacinate";
    interfaces.eth0 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
  };

  boot = {
    initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" "bcm2835-v4l2" "xhci_pci" "usbhid" "usb_storage" ];
    loader.grub.enable = false;
    # Enables the generation of /boot/extlinux/extlinux.conf
    loader.generic-extlinux-compatible.enable = true;
    # loader.raspberryPi = {
    #   enable = true;
    #   # Set the version depending on your raspberry pi. 
    #   version = 3;
    #   # We need uboot
    #   uboot.enable = true;
    #   # These two parameters are the important ones to get the
    #   # camera working. These will be appended to /boot/config.txt.
    #   firmwareConfig = ''
    #     start_x=1
    #     gpu_mem=256
    #     core_freq=250
    #     dtparam=audio=on
    #   '';
    # };
    kernelParams = [
      "console=ttyS1,115200n8"
    ];
  };

  hardware.enableRedistributableFirmware = true;
  networking.wireless.enable = true;

  sound.enable = true;
  hardware.pulseaudio.enable = true;

  systemd.services.btattach = {
    before = [ "bluetooth.service" ];
    after = [ "dev-ttyAMA0.device" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bluez}/bin/btattach -B /dev/ttyAMA0 -P bcm -S 3000000";
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
