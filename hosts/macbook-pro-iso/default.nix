{
  inputs,
  outputs,
  config,
  pkgs,
  ...
}: {
  imports =
    builtins.attrValues outputs.nixosModules
    ++ [
      # Use nixos-generators module
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      # T2Linux channel requirements
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
      # Include the T2 security chip module from nixos-hardware
      inputs.hardware.nixosModules.apple-t2
    ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # T2Linux-specific Nix settings
  nix.settings = {
    trusted-substituters = [
      "https://t2linux.cachix.org"
    ];
    trusted-public-keys = [
      "t2linux.cachix.org-1:P733c5Gt1qTcxsm+Bae0renWnT8OLs0u9+yfaK2Bejw="
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # ISO image configuration
  isoImage = {
    isoName = "nixos-macbook-pro-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
    makeEfiBootable = true;
    makeUsbBootable = true;
    # Include T2 support tools and modules in the ISO
    contents = [
      # Add any additional files you want in the ISO
      # { source = ./yourfile; target = "/path/in/iso"; }
    ];
  };

  # Enable the desktop environment in the ISO
  my = {
    users.pperanich.enable = true;
    core.enable = true;

    # Desktop environment configuration for the live environment
    desktop = {
      # Enable display manager with KDE as default
      display-manager = {
        enable = true;
        manager = "sddm";
        defaultSession = "plasma";
        autoLogin = {
          enable = true; # Auto-login for the live session
          user = "nixos"; # Default user for the live session
        };
      };

      # Enable only KDE desktop environment
      sway.enable = false;
      kde.enable = true;
    };
  };

  # Boot configuration for the ISO
  boot = {
    # T2 Mac specific kernel parameters
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
      "pcie_ports=compat"
      "pcie_aspm.policy=powersupersave"

      # Common live CD boot parameters
      "copytoram"
    ];

    # Enable keyboard in early boot
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "sd_mod"
      "sdhci_pci"
      "applespi"
      "spi_pxa2xx_platform"
    ];

    # Enable module for reading APFS volumes
    extraModulePackages = with config.boot.kernelPackages; [
      apfs
    ];
  };

  # Enable WIFI support in the ISO
  networking = {
    wireless.enable = false; # Disable wpa_supplicant
    networkmanager.enable = true; # Use NetworkManager instead
  };

  # Hardware configuration for MacBook Pro
  hardware = {
    graphics.enable = true;
    bluetooth.enable = true;

    # Apple-specific configuration
    facetimehd.enable = true; # Enable FaceTime HD camera if available
  };

  services.pulseaudio.enable = false;

  # Enable sound via pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Additional services for the live CD
  services = {
    # Enable SSH for remote help during installation
    openssh.enable = true;

    # Enable Touchpad support
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        disableWhileTyping = true;
      };
    };

    # Thermal management
    thermald.enable = true;

    # Power management (useful for laptops)
    # tlp.enable = true;
  };

  # Allow unfree packages (needed for some firmware)
  nixpkgs.config.allowUnfree = true;

  # T2Linux firmware script package
  nixpkgs.overlays = [
    (final: prev: {
      get-apple-firmware = prev.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "get-apple-firmware";
        version = "360156db52c013dbdac0ef9d6e2cebbca46b955b";
        src = prev.fetchurl {
          url = "https://raw.github.com/t2linux/wiki/${finalAttrs.version}/docs/tools/firmware.sh";
          hash = "sha256-IL7omNdXROG402N2K9JfweretTnQujY67wKKC8JgxBo=";
        };

        dontUnpack = true;

        buildPhase = ''
          mkdir -p $out/bin
          cp ${finalAttrs.src} $out/bin/get-apple-firmware
          chmod +x $out/bin/get-apple-firmware
        '';

        meta = {
          description = "A script to get needed firmware for T2linux devices";
          homepage = "https://t2linux.org";
          license = prev.lib.licenses.mit;
          maintainers = with prev.lib.maintainers; [soopyc];
          mainProgram = "get-apple-firmware";
        };
      });
    })
  ];

  # Add additional installation tools
  environment.systemPackages = with pkgs; [
    # Basic system utilities
    wget
    git
    vim
    htop

    # Disk utilities
    gparted
    parted
    gptfdisk

    # Installation helpers
    cryptsetup # For encrypted installations

    # Network tools
    iw
    wirelesstools

    # MacBook-specific utilities
    brightnessctl # Backlight control

    # T2Linux-specific tools
    python3
    dmg2img
    get-apple-firmware
  ];

  # Configure the default live CD user
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
    # Allow password-less sudo for the live user
    initialPassword = "";
  };
  security.sudo.wheelNeedsPassword = false;
}
