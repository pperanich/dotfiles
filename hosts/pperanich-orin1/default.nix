{
  inputs,
  outputs,
  pkgs,
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
    desktop = {
      # Enable display manager with Sway as default
      display-manager = {
        enable = true;
        manager = "sddm";
        defaultSession = "plasma";
        autoLogin = {
          enable = false;
          user = "pperanich"; # Change to your desired user
        };
      };

      # Enable desktop environments
      sway.enable = true;
      kde.enable = true;
    };
  };

  # Networking configuration
  networking = {
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
  environment.systemPackages = with pkgs; [
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

    # nvidia-jetpack.cudaPackages.cudatoolkit
    # nvidia-jetpack.cudaPackages.cudnn
    nvidia-jetpack.cudaPackages.tensorrt
    # nvidia-jetpack.cudaPackages.nsight_compute
    nvidia-jetpack.cudaPackages.libnvjpeg
    nvidia-jetpack.nvidia-ctk
    nvidia-jetpack.python-jetson
    nvidia-jetpack.board-automation
    nvidia-jetpack.tegra-eeprom-tool
    nvidia-jetpack.orinAgxJetsonBenchmarks
    nvidia-jetpack.otaUtils

# nvidia-jetpack.cudaPackages.cuda-command-line-tools-12-6
# nvidia-jetpack.cudaPackages."cuda-compat-12-6"
# nvidia-jetpack.cudaPackages."cuda-compiler-12-6"
# nvidia-jetpack.cudaPackages."cuda-crt-12-6"
# nvidia-jetpack.cudaPackages."cuda-cudart-12-6"
# nvidia-jetpack.cudaPackages."cuda-cudart-dev-12-6"
# nvidia-jetpack.cudaPackages."cuda-cuobjdump-12-6"
# nvidia-jetpack.cudaPackages."cuda-cupti-12-6"
# nvidia-jetpack.cudaPackages."cuda-cupti-dev-12-6"
# nvidia-jetpack.cudaPackages."cuda-cuxxfilt-12-6"
# nvidia-jetpack.cudaPackages."cuda-documentation-12-6"
# nvidia-jetpack.cudaPackages."cuda-driver-dev-12-6"
# nvidia-jetpack.cudaPackages."cuda-gdb-12-6"
# nvidia-jetpack.cudaPackages."cuda-gdb-src-12-6"
# nvidia-jetpack.cudaPackages."cuda-minimal-build-12-6"
# nvidia-jetpack.cudaPackages."cuda-nsight-compute-12-6"
# nvidia-jetpack.cudaPackages."cuda-nvcc-12-6"
# nvidia-jetpack.cudaPackages."cuda-nvdisasm-12-6"
# nvidia-jetpack.cudaPackages."cuda-nvml-dev-12-6"
# nvidia-jetpack.cudaPackages."cuda-nvprune-12-6"
# nvidia-jetpack.cudaPackages."cuda-nvrtc-12-6"
# nvidia-jetpack.cudaPackages."cuda-nvrtc-dev-12-6"
# nvidia-jetpack.cudaPackages."cuda-nvtx-12-6"
# nvidia-jetpack.cudaPackages."cuda-nvvm-12-6"
# nvidia-jetpack.cudaPackages."cuda-profiler-api-12-6"
# nvidia-jetpack.cudaPackages."cuda-sanitizer-12-6"
# nvidia-jetpack.cudaPackages."cuda-toolkit-12-6-config-common"
# nvidia-jetpack.cudaPackages."cuda-toolkit-12-config-common"
# nvidia-jetpack.cudaPackages."cuda-toolkit-config-common"
# nvidia-jetpack.cudaPackages."cuda-visual-tools-12-6"
# nvidia-jetpack.cudaPackages."cudnn"
# nvidia-jetpack.cudaPackages."cudnn9"
# nvidia-jetpack.cudaPackages."cudnn9-cuda-12"
# nvidia-jetpack.cudaPackages."cudnn9-cuda-12-6"
# nvidia-jetpack.cudaPackages."cupva-2.5-l4t"
# nvidia-jetpack.cudaPackages."deepstream-7.1"
# nvidia-jetpack.cudaPackages."gds-tools-12-6"
# nvidia-jetpack.cudaPackages."holoscan"
# nvidia-jetpack.cudaPackages."libcublas-12-6"
# nvidia-jetpack.cudaPackages."libcublas-dev-12-6"
# nvidia-jetpack.cudaPackages."libcudla-12-6"
# nvidia-jetpack.cudaPackages."libcudla-dev-12-6"
# nvidia-jetpack.cudaPackages."libcudnn9-cuda-12"
# nvidia-jetpack.cudaPackages."libcudnn9-dev-cuda-12"
# nvidia-jetpack.cudaPackages."libcudnn9-samples"
# nvidia-jetpack.cudaPackages."libcudnn9-static-cuda-12"
# nvidia-jetpack.cudaPackages."libcufft-12-6"
# nvidia-jetpack.cudaPackages."libcufft-dev-12-6"
# nvidia-jetpack.cudaPackages."libcufile-12-6"
# nvidia-jetpack.cudaPackages."libcufile-dev-12-6"
# nvidia-jetpack.cudaPackages."libcurand-12-6"
# nvidia-jetpack.cudaPackages."libcurand-dev-12-6"
# nvidia-jetpack.cudaPackages."libcusolver-12-6"
# nvidia-jetpack.cudaPackages."libcusolver-dev-12-6"
# nvidia-jetpack.cudaPackages."libcusparse-12-6"
# nvidia-jetpack.cudaPackages."libcusparse-dev-12-6"
# nvidia-jetpack.cudaPackages."libnpp-12-6"
# nvidia-jetpack.cudaPackages."libnpp-dev-12-6"
# nvidia-jetpack.cudaPackages."libnvfatbin-12-6"
# nvidia-jetpack.cudaPackages."libnvfatbin-dev-12-6"
# nvidia-jetpack.cudaPackages."libnvidia-container-tools"
# nvidia-jetpack.cudaPackages."libnvidia-container1"
# nvidia-jetpack.cudaPackages."libnvinfer-bin"
# nvidia-jetpack.cudaPackages."libnvinfer-dev"
# nvidia-jetpack.cudaPackages."libnvinfer-dispatch-dev"
# nvidia-jetpack.cudaPackages."libnvinfer-dispatch10"
# nvidia-jetpack.cudaPackages."libnvinfer-headers-dev"
# nvidia-jetpack.cudaPackages."libnvinfer-headers-plugin-dev"
# nvidia-jetpack.cudaPackages."libnvinfer-lean-dev"
# nvidia-jetpack.cudaPackages."libnvinfer-lean10"
# nvidia-jetpack.cudaPackages."libnvinfer-plugin-dev"
# nvidia-jetpack.cudaPackages."libnvinfer-plugin10"
# nvidia-jetpack.cudaPackages."libnvinfer-samples"
# nvidia-jetpack.cudaPackages."libnvinfer-vc-plugin-dev"
# nvidia-jetpack.cudaPackages."libnvinfer-vc-plugin10"
# nvidia-jetpack.cudaPackages."libnvinfer10"
# nvidia-jetpack.cudaPackages."libnvjitlink-12-6"
# nvidia-jetpack.cudaPackages."libnvjitlink-dev-12-6"
# nvidia-jetpack.cudaPackages."libnvjpeg-12-6"
# nvidia-jetpack.cudaPackages."libnvjpeg-dev-12-6"
# nvidia-jetpack.cudaPackages."libnvonnxparsers-dev"
# nvidia-jetpack.cudaPackages."libnvonnxparsers10"
# nvidia-jetpack.cudaPackages."libnvvpi3"
# nvidia-jetpack.cudaPackages."libopencv"
# nvidia-jetpack.cudaPackages."libopencv-dev"
# nvidia-jetpack.cudaPackages."libopencv-python"
# nvidia-jetpack.cudaPackages."libopencv-samples"
# nvidia-jetpack.cudaPackages."nsight-compute-2024.3.1"
# nvidia-jetpack.cudaPackages."nsight-graphics-for-embeddedlinux-2024.2.0.0"
# nvidia-jetpack.cudaPackages."nsight-systems-2024.5.4"
# nvidia-jetpack.cudaPackages."nvidia-container"
# nvidia-jetpack.cudaPackages."nvidia-container-toolkit"
# nvidia-jetpack.cudaPackages."nvidia-container-toolkit-base"
# nvidia-jetpack.cudaPackages."nvidia-cuda"
# nvidia-jetpack.cudaPackages."nvidia-cuda-dev"
# nvidia-jetpack.cudaPackages."nvidia-cudnn"
# nvidia-jetpack.cudaPackages."nvidia-cudnn-dev"
# nvidia-jetpack.cudaPackages."nvidia-cudnn9"
# nvidia-jetpack.cudaPackages."nvidia-cudnn9-dev"
# nvidia-jetpack.cudaPackages."nvidia-cupva"
# nvidia-jetpack.cudaPackages."nvidia-fs"
# nvidia-jetpack.cudaPackages."nvidia-fs-dkms"
# nvidia-jetpack.cudaPackages."nvidia-jetpack"
# nvidia-jetpack.cudaPackages."nvidia-jetpack-dev"
# nvidia-jetpack.cudaPackages."nvidia-jetpack-runtime"
# nvidia-jetpack.cudaPackages."nvidia-jetson-services"
# nvidia-jetpack.cudaPackages."nvidia-l4t-cudadebuggingsupport"
# nvidia-jetpack.cudaPackages."nvidia-l4t-dla-compiler"
# nvidia-jetpack.cudaPackages."nvidia-l4t-gstreamer"
# nvidia-jetpack.cudaPackages."nvidia-l4t-jetson-multimedia-api"
# nvidia-jetpack.cudaPackages."nvidia-nsight-graphics"
# nvidia-jetpack.cudaPackages."nvidia-nsight-systems"
# nvidia-jetpack.cudaPackages."nvidia-opencv"
# nvidia-jetpack.cudaPackages."nvidia-opencv-dev"
# nvidia-jetpack.cudaPackages."nvidia-tensorrt"
# nvidia-jetpack.cudaPackages."nvidia-tensorrt-dev"
# nvidia-jetpack.cudaPackages."nvidia-vpi"
# nvidia-jetpack.cudaPackages."nvidia-vpi-dev"
# nvidia-jetpack.cudaPackages."opencv-licenses"
# nvidia-jetpack.cudaPackages."opencv-samples-data"
# nvidia-jetpack.cudaPackages."pva-allow-2"
# nvidia-jetpack.cudaPackages."pva-sdk-2.5-l4t"
# nvidia-jetpack.cudaPackages."python3-libnvinfer"
# nvidia-jetpack.cudaPackages."python3-libnvinfer-dev"
# nvidia-jetpack.cudaPackages."python3-libnvinfer-dispatch"
# nvidia-jetpack.cudaPackages."python3-libnvinfer-lean"
# nvidia-jetpack.cudaPackages."python3.10-vpi3"
# nvidia-jetpack.cudaPackages."tensorrt"
# nvidia-jetpack.cudaPackages."tensorrt-dev"
# nvidia-jetpack.cudaPackages."tensorrt-libs"
# nvidia-jetpack.cudaPackages."vpi3-dev"
# nvidia-jetpack.cudaPackages."vpi3-python-src"
# nvidia-jetpack.cudaPackages."vpi3-samples"
# nvidia-jetpack."jetson-gpio-common"
# nvidia-jetpack."nvidia-igx-bootloader"
# nvidia-jetpack."nvidia-igx-oem-config"
# nvidia-jetpack."nvidia-igx-systemd-reboot-hooks"
# nvidia-jetpack."nvidia-l4t-3d-core"
# nvidia-jetpack."nvidia-l4t-apt-source"
# nvidia-jetpack."nvidia-l4t-bootloader"
# nvidia-jetpack."nvidia-l4t-camera"
# nvidia-jetpack."nvidia-l4t-configs"
# nvidia-jetpack."nvidia-l4t-core"
# nvidia-jetpack."nvidia-l4t-cuda"
# nvidia-jetpack."nvidia-l4t-cuda-utils"
# nvidia-jetpack."nvidia-l4t-dgpu-tools"
# nvidia-jetpack."nvidia-l4t-display-kernel"
# nvidia-jetpack."nvidia-l4t-factory-service"
# nvidia-jetpack."nvidia-l4t-firmware"
# nvidia-jetpack."nvidia-l4t-gbm"
# nvidia-jetpack."nvidia-l4t-graphics-demos"
# nvidia-jetpack."nvidia-l4t-init"
# nvidia-jetpack."nvidia-l4t-initrd"
# nvidia-jetpack."nvidia-l4t-jetson-io"
# nvidia-jetpack."nvidia-l4t-jetson-orin-nano-qspi-updater"
# nvidia-jetpack."nvidia-l4t-jetsonpower-gui-tools"
# nvidia-jetpack."nvidia-l4t-kernel"
# nvidia-jetpack."nvidia-l4t-kernel-dtbs"
# nvidia-jetpack."nvidia-l4t-kernel-headers"
# nvidia-jetpack."nvidia-l4t-kernel-oot-headers"
# nvidia-jetpack."nvidia-l4t-kernel-oot-modules"
# nvidia-jetpack."nvidia-l4t-libwayland-client0"
# nvidia-jetpack."nvidia-l4t-libwayland-cursor0"
# nvidia-jetpack."nvidia-l4t-libwayland-egl1"
# nvidia-jetpack."nvidia-l4t-libwayland-server0"
# nvidia-jetpack."nvidia-l4t-multimedia"
# nvidia-jetpack."nvidia-l4t-multimedia-utils"
# nvidia-jetpack."nvidia-l4t-nvfancontrol"
# nvidia-jetpack."nvidia-l4t-nvml"
# nvidia-jetpack."nvidia-l4t-nvpmodel"
# nvidia-jetpack."nvidia-l4t-nvpmodel-gui-tools"
# nvidia-jetpack."nvidia-l4t-nvsci"
# nvidia-jetpack."nvidia-l4t-oem-config"
# nvidia-jetpack."nvidia-l4t-openwfd"
# nvidia-jetpack."nvidia-l4t-optee"
# nvidia-jetpack."nvidia-l4t-pva"
# nvidia-jetpack."nvidia-l4t-tools"
# nvidia-jetpack."nvidia-l4t-vulkan-sc"
# nvidia-jetpack."nvidia-l4t-vulkan-sc-dev"
# nvidia-jetpack."nvidia-l4t-vulkan-sc-samples"
# nvidia-jetpack."nvidia-l4t-vulkan-sc-sdk"
# nvidia-jetpack."nvidia-l4t-wayland"
# nvidia-jetpack."nvidia-l4t-weston"
# nvidia-jetpack."nvidia-l4t-x11"
# nvidia-jetpack."nvidia-l4t-xusb-firmware"
# nvidia-jetpack."python-jetson-gpio"
# nvidia-jetpack."python3-jetson-gpio"
  ] 
  ++ builtins.attrValues pkgs.nvidia-jetpack.tests; 
  # ++ builtins.attrValues pkgs.nvidia-jetpack.samples;

  # Just ensure containers are enabled by boot.
    boot.enableContainers = true;

  # Enable Opengl renamed to hardware.graphics.enable
  hardware.graphics.enable = true;
  # hardware.nvidia-container-toolkit.enable = true;

  # Docker Daemon Settings
    virtualisation.docker = {
      # To force Docker package version settings need to import pkgs first
      # package = pkgs.docker_26;

      enable = true;
      # The enableNvidia option is still used in jetpack-nixos while it is obsolete in nixpkgs
      # but it is still only option for nvidia-orin devices. Added extra fix for CDI to
      # make it run with docker.
      enableNvidia = true;
      daemon.settings.features.cdi = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
        daemon.settings.features.cdi = true;
        daemon.settings.cdi-spec-dirs = [ "/var/run/cdi/" ];
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
      enableNvidia = true;
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
    som = "orin-agx";
    carrierBoard = "devkit";
  };

  # services.nvpmodel.profileNumber = 0;

  # Avoid kernel crashes
  boot.kernelParams = [ "initcall_blacklist=tegra_se_module_init" ];

  # hardware.opengl.enable = true;

  time.timeZone = "America/New_York";
}
