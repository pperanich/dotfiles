{
  inputs,
  modules,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # Use minimal installation module
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    # T2Linux channel requirements
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    # Include the T2 security chip module from nixos-hardware
    inputs.hardware.nixosModules.apple-t2
  ]
  ++ (with modules.nixos; [
    # Minimal installer with essential tools
    base
    fileExploration
    networkUtilities
  ]);

  # Network configuration for ISO
  networking = {
    wireless.enable = true; # Enable wpa_supplicant for WiFi
    wireless.userControlled.enable = true;
    networkmanager.enable = lib.mkForce false; # Disable NetworkManager to avoid conflict
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ]; # Open SSH port
    };
  };

  # Enable SSH for nixos-anywhere
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkForce "yes";
      PasswordAuthentication = lib.mkForce true;
    };
  };

  nixpkgs = {
    hostPlatform = "x86_64-linux";
    # Allow unfree packages (needed for some firmware)
    config.allowUnfree = true;
    # T2Linux firmware script package
    overlays = [
      (_final: prev: {
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
            maintainers = with prev.lib.maintainers; [ soopyc ];
            mainProgram = "get-apple-firmware";
          };
        });
      })
    ];
  };

  # Essential tools for network setup and remote installation
  environment.systemPackages = with pkgs; [
    # Basic system utilities
    wget
    git
    vim
    htop
    curl

    # Network tools
    iwd
    iw
    wirelesstools
    networkmanager # For nmcli
    bind.dnsutils # For nslookup, dig

    # Disk utilities
    parted
    gptfdisk
    cryptsetup # For encrypted installations

    # T2Linux-specific tools
    python3
    dmg2img
    get-apple-firmware
  ];
}
