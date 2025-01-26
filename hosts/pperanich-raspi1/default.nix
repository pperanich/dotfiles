{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ../shared/core
    ../shared/users/pperanich
    ../shared/optional/tailscale.nix
    ../shared/optional/couchdb.nix
  ];

  sdImage.compressImage = false;

  environment.systemPackages = with pkgs; [
    libraspberrypi
  ];

  networking = {
    hostName = "pperanich-raspi1";
    useDHCP = true;
    wireless = {
      enable = true;
      networks."VirusInfectedWifi".psk = "vacinate";
      interfaces = ["wlan0"];
    };
    interfaces.eth0 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
  };

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi3;
    # initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" "bcm2835-v4l2" "xhci_pci" "usbhid" "usb_storage" ];
    loader.grub.enable = false;
    # Enables the generation of /boot/extlinux/extlinux.conf
    loader.generic-extlinux-compatible.enable = true;
    kernelParams = [
      "cma=256M"
    ];
  };

  hardware.enableRedistributableFirmware = true;

  sound.enable = true;
  hardware.pulseaudio.enable = true;

  systemd.services.btattach = {
    before = ["bluetooth.service"];
    after = ["dev-ttyAMA0.device"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.bluez}/bin/btattach -B /dev/ttyAMA0 -P bcm -S 3000000";
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
