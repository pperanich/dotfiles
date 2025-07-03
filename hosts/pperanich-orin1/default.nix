{
  inputs,
  outputs,
  pkgs,
  lib,
  ...
}: {
  imports =
    builtins.attrValues outputs.nixosModules
    ++ [
      inputs.disko.nixosModules.disko
      ./disko-config.nix
      ./hardware-configuration.nix
      inputs.jetpack-nixos.nixosModules.default
    ];

  # Core system configuration
  my = {
    core.enable = true;
    users.pperanich.enable = true; # Adjust this to your username
    # virtualization.docker = {
    #   enable = true;
    #   enableNvidia = true;
    # };

    # Desktop environment configuration
    # desktop = {
    #   # Enable display manager with Sway as default
    #   display-manager = {
    #     enable = true;
    #     manager = "sddm";
    #     defaultSession = "plasma";
    #     autoLogin = {
    #       enable = false;
    #       user = "pperanich"; # Change to your desired user
    #     };
    #   };
    #
    #   # Enable desktop environments
    #   sway.enable = true;
    #   kde.enable = true;
    # };
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia.open = false;

  # Need to add gdm user to video group.
  users.users.gdm = { extraGroups = [ "video" ]; };
  # enable Gnome
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.wayland = false;
  programs.dconf.enable = true;


  # Networking configuration
  networking = {
    networkmanager.enable = lib.mkForce false;
    hostName = "pperanich-orin1";
    wireless.enable = true;
    wireless.userControlled.enable = true;
    wireless.networks."VirusInfectedWifi".psk = "vacinate";
    useDHCP = true;
  };

  # Additional services
  services = {
    # Enable SSH
    openssh.enable = true;

    # Enable printing
    printing.enable = true;
  };

  # Allow unfree packages (needed for some firmware)
  nixpkgs.config.allowUnfree = true;

  # Package configuration
  environment.systemPackages = with pkgs;
    [
      # Basic system utilities
      wget
      git
      htop
      neofetch

      # Graphics drivers
      mesa
      vulkan-loader
      vulkan-tools

      # Firmware updates
      fwupd

      nvidia-jetpack.nvidia-ctk
      nvidia-jetpack.python-jetson
      nvidia-jetpack.board-automation
      nvidia-jetpack.tegra-eeprom-tool
      nvidia-jetpack.orinAgxJetsonBenchmarks
      nvidia-jetpack.otaUtils

      nvidia-jetpack.cudaPackages.cuda_cudart
      nvidia-jetpack.cudaPackages.cuda_cuobjdump
      nvidia-jetpack.cudaPackages.cuda_gdb
      nvidia-jetpack.cudaPackages.cuda_nvcc
      nvidia-jetpack.cudaPackages.cuda_nvdisasm
      nvidia-jetpack.cudaPackages.cuda_nvprune
      nvidia-jetpack.cudaPackages.cuda_nvrtc
      nvidia-jetpack.cudaPackages.cuda_nvtx
      nvidia-jetpack.cudaPackages.cuda_profiler_api
      nvidia-jetpack.cudaPackages.cuda_sanitizer_api
      nvidia-jetpack.cudaPackages.cudnn
      nvidia-jetpack.cudaPackages.libcublas
      nvidia-jetpack.cudaPackages.libcudla
      nvidia-jetpack.cudaPackages.libcufft
      nvidia-jetpack.cudaPackages.libcurand
      nvidia-jetpack.cudaPackages.libcusolver
      nvidia-jetpack.cudaPackages.libcusparse
      nvidia-jetpack.cudaPackages.libnpp
      nvidia-jetpack.cudaPackages.libnvjitlink
      nvidia-jetpack.cudaPackages.libnvjpeg
      nvidia-jetpack.cudaPackages.tensorrt
      nvidia-jetpack.cudaPackages.vpi-firmware
      nvidia-jetpack.cudaPackages.cudatoolkit
      # nvidia-jetpack.samples.combined-test
      nvidia-jetpack.samples.cuda-test
    ]
    ++ builtins.attrValues pkgs.nvidia-jetpack.tests;

  # Just ensure containers are enabled by boot.
  boot.enableContainers = true;

  # Enable Opengl renamed to hardware.graphics.enable
  hardware.graphics.enable = true;
  # hardware.nvidia-container-toolkit.enable = true;

  # Docker Daemon Settings
  # I think the following helped fix nvidia container woes: https://stackoverflow.com/questions/75118992/docker-error-response-from-daemon-could-not-select-device-driver-with-capab
  virtualisation.docker = {
    # To force Docker package version settings need to import pkgs first
    package = pkgs.docker_28;

    enable = true;
    # The enableNvidia option is still used in jetpack-nixos while it is obsolete in nixpkgs
    # but it is still only option for nvidia-orin devices. Added extra fix for CDI to
    # make it run with docker.
    # enableNvidia = true;
    daemon.settings.features.cdi = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
      daemon.settings.features.cdi = true;
      daemon.settings.cdi-spec-dirs = ["/var/run/cdi/"];
    };

    # Container file and processor limits
    # daemon.settings = {
    #   default-ulimits = {
    #       nofile = {
    #       Name = "nofile";
    #       Hard = 1024;
    #       Soft = 1024;
    #       };
    #       nproc = {
    #       Name = "nproc";
    #       Soft = 65536;
    #       Hard = 65536;
    #       };
    #     };
    #   };
  };

  virtualisation.podman = {
    enable = true;
    # The enableNvidia option is still used in jetpack-nixos while it is obsolete in nixpkgs
    # but it is still only option for nvidia-orin devices.
    # enableNvidia = true;
    defaultNetwork.settings.dns_enabled = true;
    # Container file and processor limits
    # daemon.settings = {
    #   default-ulimits = {
    #       nofile = {
    #       Name = "nofile";
    #       Hard = 1024;
    #       Soft = 1024;
    #       };
    #       nproc = {
    #       Name = "nproc";
    #       Soft = 65536;
    #       Hard = 65536;
    #       };
    #     };
    #   };
  };

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };


  hardware.nvidia-jetpack = {
    enable = true;
    majorVersion = "6";
    som = "orin-agx";
    carrierBoard = "devkit";
    container-toolkit.enable = true;
    # modesetting.enable = true;
  };

  services.nvpmodel.profileNumber = 0;

  # Avoid kernel crashes
  boot.kernelParams = ["initcall_blacklist=tegra_se_module_init"];

  # hardware.opengl.enable = true;

  time.timeZone = "America/New_York";
}
