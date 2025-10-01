_: {
  # NixOS system-level QEMU/KVM configuration
  flake.modules.nixos.qemu =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.features.qemu;
    in
    {
      options.features.qemu = {
        enableGuestAgent = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable QEMU guest agent support";
        };
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
          default = [ ];
          example = "[ pkgs.virt-viewer ]";
          description = "Additional packages to install with QEMU/KVM";
        };
      };

      config = {
        # Enable core virtualization support
        virtualisation.libvirtd = {
          enable = true;
          qemu = {
            package = pkgs.qemu_kvm;
            runAsRoot = true;
            swtpm.enable = true;
            ovmf = {
              enable = true;
              packages = [ pkgs.OVMFFull.fd ];
            };
          };
          onBoot = "ignore";
          onShutdown = "shutdown";
        };

        # Add virtualization packages to the system environment
        environment.systemPackages =
          with pkgs;
          [
            virtiofsd
          ]
          ++ lib.optionals cfg.enableVirtManager [
            virt-manager
          ]
          ++ lib.optionals cfg.enableSpiceSupport [
            spice
            spice-gtk
            spice-protocol
          ]
          ++ cfg.extraPackages;

        # QEMU guest agent for VMs running NixOS
        services.qemuGuest.enable = cfg.enableGuestAgent;

        # Load appropriate kernel modules
        boot.kernelModules = [
          "kvm-intel"
          "kvm-amd"
        ];

        # Networking configuration for VMs
        networking.firewall.checkReversePath = false;

        # Ensure dconf is properly set up for virt-manager
        programs.dconf.enable = lib.mkIf cfg.enableVirtManager true;
      };
    };

  # Home Manager user-level virtualization tools
  flake.modules.homeManager.qemu =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # VM management and utilities
        virt-viewer # SPICE/VNC client for VMs
        virt-top # Top-like utility for VMs
        guestfs-tools # Guest filesystem tools

        # Development and testing tools
        vagrant # Development environment management
      ];
    };
}
