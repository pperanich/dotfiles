{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ ];

  boot = {
    initrd = {
      availableKernelModules = [ "virtio_pci" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-amd" ];
    extraModulePackages = [ ];
  };

  #fileSystems."/" =
  #  { device = "/dev/sdc";
  #    fsType = "ext4";
  #  };

  #fileSystems."/usr/lib/wsl/drivers" =
  #  { device = "none";
  #    fsType = "9p";
  #  };

  #fileSystems."/usr/lib/wsl/lib" =
  #  { device = "none";
  #    fsType = "overlay";
  #  };

  #fileSystems."/mnt/wsl" =
  #  { device = "none";
  #    fsType = "tmpfs";
  #  };

  #fileSystems."/mnt/wslg" =
  #  { device = "none";
  #    fsType = "tmpfs";
  #  };

  #fileSystems."/mnt/wslg/distro" =
  #  { device = "";
  #    fsType = "none";
  #    options = [ "bind" ];
  #  };

  #fileSystems."/mnt/wslg/doc" =
  #  { device = "none";
  #    fsType = "overlay";
  #  };

  #fileSystems."/tmp/.X11-unix" =
  #  { device = "/mnt/wslg/.X11-unix";
  #    fsType = "none";
  #    options = [ "bind" ];
  #  };

  #fileSystems."/mnt/c" =
  #  { device = "drvfs";
  #    fsType = "9p";
  #  };

  #fileSystems."/mnt/d" =
  #  { device = "drvfs";
  #    fsType = "9p";
  #  };

  #swapDevices =
  #  [ { device = "/dev/sdb"; }
  #  ];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
