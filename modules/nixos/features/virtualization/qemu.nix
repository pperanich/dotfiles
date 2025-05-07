# QEMU/KVM virtualization module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.features.virtualization.qemu;
in {
  options.my.features.virtualization.qemu = {
    enable = lib.mkEnableOption "QEMU/KVM virtualization";
    enableGuestAgent = lib.mkEnableOption "QEMU guest agent support";
    enableVirtManager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable virt-manager for GUI management";
    };
    enableSpiceSupport = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SPICE support for better desktop integration";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = "[ pkgs.virt-viewer ]";
      description = "Additional packages to install with QEMU/KVM";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable core virtualization support
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [pkgs.OVMFFull.fd];
        };
      };
      onBoot = "ignore";
      onShutdown = "shutdown";
    };

    # Add appropriate packages to the system environment
    environment.systemPackages = with pkgs;
      [
        virt-manager
        virtiofsd
        spice
        spice-gtk
        spice-protocol
      ]
      ++ lib.optionals (!cfg.enableVirtManager) []
      ++ lib.optionals (!cfg.enableSpiceSupport) []
      ++ cfg.extraPackages;

    # QEMU guest agent for VMs running NixOS
    services.qemuGuest.enable = cfg.enableGuestAgent;

    # Add user to libvirtd group if module is enabled
    # users.groups.libvirtd.members = config.my.user.groups;

    # Load appropriate kernel modules
    boot.kernelModules = ["kvm-intel" "kvm-amd"];

    # Networking for VMs
    networking.firewall.checkReversePath = false;

    # Ensure dconf is properly set up for virt-manager
    programs.dconf.enable = lib.mkIf cfg.enableVirtManager true;
  };
}
