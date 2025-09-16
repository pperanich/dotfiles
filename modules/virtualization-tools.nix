# Comprehensive virtualization and emulation tools module
# Provides hypervisors, VM management, emulation platforms, and sandbox environments
# Supports NixOS, Darwin, and Home Manager configurations
_: {
  # NixOS system configuration
  flake.modules.nixos.virtualizationTools = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.virtualization;
  in {
    options.features.virtualization = {
      hypervisor = lib.mkOption {
        type = lib.types.enum ["qemu" "libvirt" "both"];
        default = "libvirt";
        description = "Primary hypervisor to configure (qemu, libvirt, or both)";
      };

      enableKvm = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable KVM hardware acceleration (Linux only)";
      };

      bridgeNetworking = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable bridge networking for VMs";
      };

      enableSpice = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SPICE remote display system";
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        example = "[ pkgs.looking-glass-client ]";
        description = "Additional virtualization packages to install system-wide";
      };
    };

    config = {
      # Core virtualization support
      virtualisation = lib.mkMerge [
        (lib.mkIf (cfg.hypervisor == "libvirt" || cfg.hypervisor == "both") {
          libvirtd = {
            enable = true;
            qemu = {
              package = pkgs.qemu_kvm;
              runAsRoot = false;
              swtpm.enable = true; # TPM emulation
              ovmf.enable = true; # UEFI support
            };
          };
        })

        # KVM acceleration
        (lib.mkIf cfg.enableKvm {
          kvmgt.enable = true;
        })

        # Spice support
        (lib.mkIf cfg.enableSpice {
          spiceUSBRedirection.enable = true;
        })
      ];

      # System packages for virtualization
      environment.systemPackages = with pkgs;
        [
          # Core hypervisor tools
          qemu_full # QEMU with all targets
          qemu-utils # QEMU utilities (qemu-img, etc.)

          # Libvirt management
          libvirt # Virtualization API
          virt-manager # GUI for managing VMs
          virt-viewer # VM display client
          virtiofsd # VirtIO file system daemon

          # VM management tools
          vagrant # Development environment management
          packer # Machine image builder

          # Cloud and image tools
          cloud-init # Cloud instance initialization
          virt-install # Command line VM installer
          virt-clone # VM cloning tool
          libguestfs-with-appliance # Guest disk image tools

          # Network virtualization
          bridge-utils # Bridge networking utilities

          # Emulation platforms
          wine # Windows compatibility layer
          dosbox # DOS emulator
          scummvm # Adventure game engine

          # Sandbox environments
          firejail # Application sandboxing
          bubblewrap # Sandboxing tool
          nsjail # Process isolation tool

          # Additional user-specified packages
        ]
        ++ cfg.extraPackages;

      # Kernel modules for virtualization
      boot.kernelModules = [
        "kvm"
        "kvm-intel"
        "kvm-amd"
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
        "vfio_virqfd"
      ];

      # Kernel parameters for virtualization
      boot.kernelParams = [
        "intel_iommu=on" # Intel IOMMU support
        "iommu=pt" # IOMMU passthrough
      ];

      # Enable nested virtualization
      boot.extraModprobeConfig = ''
        options kvm_intel nested=1
        options kvm_amd nested=1
      '';

      # Security settings for virtualization
      security.wrappers = lib.mkIf cfg.enableKvm {
        qemu-bridge-helper = {
          source = "${pkgs.qemu}/libexec/qemu-bridge-helper";
          capabilities = "cap_net_admin+ep";
          owner = "root";
          group = "kvm";
          permissions = "u+rx,g+rx";
        };
      };

      # Bridge networking configuration
      networking = lib.mkIf cfg.bridgeNetworking {
        bridges.virbr0.interfaces = [];
        interfaces.virbr0 = {
          ipv4.addresses = [
            {
              address = "192.168.122.1";
              prefixLength = 24;
            }
          ];
        };
        # Firewall rules for virtualization
        firewall = {
          trustedInterfaces = ["virbr0"];
          allowedUDPPorts = [67 68]; # DHCP
        };
      };

      # Users and groups for virtualization
      users.groups = {
        libvirtd = {};
        kvm = {};
      };

      # System services
      systemd.services = {
        # Custom libvirt network setup
        libvirt-guests = lib.mkIf (cfg.hypervisor == "libvirt" || cfg.hypervisor == "both") {
          enable = true;
          wantedBy = ["multi-user.target"];
        };
      };

      # Polkit rules for libvirt access
      security.polkit.enable = true;
      security.polkit.extraConfig = lib.mkIf (cfg.hypervisor == "libvirt" || cfg.hypervisor == "both") ''
        polkit.addRule(function(action, subject) {
            if (action.id == "org.libvirt.unix.manage" &&
                subject.isInGroup("libvirtd")) {
                    return polkit.Result.YES;
            }
        });
      '';
    };
  };

  # Home Manager user configuration
  flake.modules.homeModules.virtualizationTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # VM management tools
        vagrant # Development environment orchestration
        packer # Automated machine image creation

        # QEMU utilities
        qemu-utils # Image manipulation tools

        # Remote access and display
        virt-viewer # VM console access
        spice-gtk # SPICE client libraries
        remmina # Remote desktop client

        # Cloud tools
        cloud-init # Cloud VM initialization

        # Emulation and compatibility
        wine # Windows application compatibility
        winetricks # Wine configuration utility
        dosbox # DOS game emulation
        scummvm # Classic adventure games

        # Development VMs
        lima # Linux VMs on macOS

        # Container-like virtualization
        podman-compose # For lightweight VM alternatives
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific virtualization tools
        virt-manager # GUI VM management
        libvirt # Virtualization library
        virtiofsd # VirtIO filesystem daemon

        # Linux sandboxing
        firejail # Application sandboxing
        bubblewrap # Low-level sandboxing
        nsjail # Process isolation

        # Linux-specific emulation
        qemu_full # Full QEMU with all architectures
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific tools handled via homebrew in darwin module
        lima # Linux VMs for macOS
        colima # Container runtime on macOS
      ];

    # Development environment variables
    home.sessionVariables = {
      # Vagrant configuration
      VAGRANT_DEFAULT_PROVIDER = lib.mkDefault "libvirt";

      # QEMU configuration
      QEMU_SYSTEM_PREFIX = "${pkgs.qemu}/bin/";

      # Wine configuration
      WINEARCH = lib.mkDefault "win64";
      WINEPREFIX = lib.mkDefault "$HOME/.wine";
    };

    # Shell aliases for virtualization workflows
    home.shellAliases = {
      # Vagrant shortcuts
      vup = "vagrant up";
      vdown = "vagrant halt";
      vreload = "vagrant reload";
      vssh = "vagrant ssh";
      vstatus = "vagrant status";
      vdestroy = "vagrant destroy";

      # VM management
      vm-list = "virsh list --all";
      vm-start = "virsh start";
      vm-stop = "virsh shutdown";
      vm-reboot = "virsh reboot";
      vm-info = "virsh dominfo";

      # QEMU utilities
      qemu-img-info = "qemu-img info";
      qemu-img-create = "qemu-img create -f qcow2";
      qemu-img-convert = "qemu-img convert";
      qemu-img-resize = "qemu-img resize";

      # Virtualization monitoring
      vm-monitor = "watch -n 2 'virsh list --all && echo && virsh pool-list --all'";
      vm-performance = "virsh domstats";

      # Emulation shortcuts
      dosbox-conf = "dosbox -conf ~/.dosboxrc";
      wine-config = "winecfg";
      wine-uninstaller = "wine uninstaller";

      # Sandbox environments
      jail = "firejail";
      sandbox = "bubblewrap --ro-bind / / --tmpfs /tmp --tmpfs /var --tmpfs /run --symlink usr/lib /lib --symlink usr/lib64 /lib64 --proc /proc --dev /dev --tmpfs /home";
    };

    # Shell functions for advanced virtualization workflows
    home.file.".config/virtualization/functions.sh" = {
      text = ''
        #!/bin/bash

        # Quick VM creation function
        vm-create() {
          local name="$1"
          local os="$2"
          local memory="$3"
          local disk="$4"

          if [ -z "$name" ] || [ -z "$os" ] || [ -z "$memory" ] || [ -z "$disk" ]; then
            echo "Usage: vm-create <name> <os> <memory_mb> <disk_gb>"
            echo "Example: vm-create ubuntu22 ubuntu22.04 2048 20"
            return 1
          fi

          virt-install \
            --name "$name" \
            --os-type linux \
            --os-variant "$os" \
            --ram "$memory" \
            --vcpus 2 \
            --disk path="/var/lib/libvirt/images/$name.qcow2,size=$disk" \
            --graphics spice \
            --network bridge=virbr0 \
            --cdrom "$HOME/Downloads/''${os}.iso" \
            --noautoconsole
        }

        # VM snapshot management
        vm-snapshot() {
          local vm="$1"
          local action="$2"
          local snapshot_name="$3"

          case "$action" in
            create)
              virsh snapshot-create-as --domain "$vm" --name "$snapshot_name" --description "Snapshot created $(date)"
              ;;
            restore)
              virsh snapshot-revert --domain "$vm" --snapshotname "$snapshot_name"
              ;;
            list)
              virsh snapshot-list --domain "$vm"
              ;;
            delete)
              virsh snapshot-delete --domain "$vm" --snapshotname "$snapshot_name"
              ;;
            *)
              echo "Usage: vm-snapshot <vm_name> <create|restore|list|delete> [snapshot_name]"
              ;;
          esac
        }

        # Quick development environment setup
        dev-env() {
          local env_name="$1"
          local box="$2"

          if [ -z "$env_name" ] || [ -z "$box" ]; then
            echo "Usage: dev-env <environment_name> <vagrant_box>"
            echo "Example: dev-env myproject ubuntu/jammy64"
            return 1
          fi

          mkdir -p "$HOME/Development/VMs/$env_name"
          cd "$HOME/Development/VMs/$env_name"

          cat > Vagrantfile << EOF
        Vagrant.configure("2") do |config|
          config.vm.box = "$box"
          config.vm.hostname = "$env_name"

          config.vm.provider "libvirt" do |libvirt|
            libvirt.memory = 2048
            libvirt.cpus = 2
          end

          config.vm.network "private_network", type: "dhcp"

          config.vm.provision "shell", inline: <<-SHELL
            apt-get update
            apt-get install -y build-essential curl git
          SHELL
        end
        EOF

          vagrant up
          echo "Development environment '$env_name' created and started."
          echo "Connect with: vagrant ssh"
        }

        # Wine prefix management
        wine-prefix() {
          local action="$1"
          local prefix_name="$2"

          case "$action" in
            create)
              export WINEPREFIX="$HOME/.wine-prefixes/$prefix_name"
              mkdir -p "$WINEPREFIX"
              winecfg
              ;;
            use)
              export WINEPREFIX="$HOME/.wine-prefixes/$prefix_name"
              echo "Using Wine prefix: $WINEPREFIX"
              ;;
            list)
              ls -la "$HOME/.wine-prefixes/"
              ;;
            remove)
              rm -rf "$HOME/.wine-prefixes/$prefix_name"
              echo "Removed Wine prefix: $prefix_name"
              ;;
            *)
              echo "Usage: wine-prefix <create|use|list|remove> [prefix_name]"
              ;;
          esac
        }
      '';
      executable = true;
    };

    # Source virtualization functions in shell
    programs.bash.initExtra = ''
      source ~/.config/virtualization/functions.sh
    '';

    programs.zsh.initExtra = ''
      source ~/.config/virtualization/functions.sh
    '';

    # Git configuration for VM-related development
    programs.git.extraConfig = {
      # Ignore common VM files
      core.excludesFile = "~/.gitignore_global";
    };

    # Global gitignore for virtualization artifacts
    home.file.".gitignore_global".text = ''
      # Vagrant
      .vagrant/
      *.box

      # VirtualBox
      *.vdi
      *.vmdk
      *.vbox
      *.vbox-prev

      # QEMU/KVM
      *.qcow2
      *.img
      *.iso

      # VMware
      *.vmx
      *.vmxf
      *.nvram
      *.vmsd

      # Packer
      packer_cache/
      *.box

      # Wine
      .wine/
      .wine-prefixes/
    '';

    # VSCode extensions for virtualization development (if VSCode is enabled)
    programs.vscode.extensions = lib.mkIf (config.programs.vscode.enable or false) (with pkgs.vscode-extensions; [
      ms-vscode-remote.remote-ssh # SSH into VMs
      hashicorp.terraform # Infrastructure as code
      redhat.vscode-yaml # For cloud-init and Vagrant configs
    ]);

    # Configuration files for tools
    xdg.configFile = {
      # Dosbox configuration
      "dosbox/dosbox.conf" = {
        text = ''
          [sdl]
          fullscreen=false
          fulldouble=false
          fullresolution=1024x768
          windowresolution=1024x768
          output=opengl
          autolock=true
          sensitivity=100
          waitonerror=true
          priority=higher,normal
          mapperfile=mapper-0.74.map
          usescancodes=true

          [dosbox]
          language=
          machine=svga_s3
          captures=capture
          memsize=16

          [render]
          frameskip=0
          aspect=false
          scaler=normal2x

          [cpu]
          core=auto
          cputype=auto
          cycles=auto
          cycleup=10
          cycledown=20

          [mixer]
          nosound=false
          rate=44100
          blocksize=1024
          prebuffer=20

          [midi]
          mpu401=intelligent
          mididevice=default
          midiconfig=

          [sblaster]
          sbtype=sb16
          sbbase=220
          irq=7
          dma=1
          hdma=5
          sbmixer=true
          oplmode=auto
          oplemu=default
          oplrate=44100

          [gus]
          gus=false
          gusrate=44100
          gusbase=240
          gusirq=5
          gusdma=3
          ultradir=C:\ULTRASND

          [speaker]
          pcspeaker=true
          pcrate=44100
          tandy=auto
          tandyrate=44100
          disney=true

          [joystick]
          joysticktype=auto
          timed=true
          autofire=false
          swap34=false
          buttonwrap=false

          [serial]
          serial1=dummy
          serial2=dummy
          serial3=disabled
          serial4=disabled

          [dos]
          xms=true
          ems=true
          umb=true
          keyboardlayout=auto

          [ipx]
          ipx=false

          [autoexec]
          # Lines in this section will be run at startup.
        '';
      };

      # ScummVM configuration
      "scummvm/scummvm.ini" = {
        text = ''
          [scummvm]
          gfx_mode=opengl
          fullscreen=false
          aspect_ratio=false
          filtering=false
          confirm_exit=true
          console=false

          [cloud]
          storage_type=none

          [gui]
          renderer=opengl
          theme=builtin

          [audio]
          output_rate=44100
          opl_driver=db
        '';
      };

      # Firejail profiles directory
      "firejail/sandbox.profile" = {
        text = ''
          # Custom sandbox profile for development
          include /etc/firejail/disable-common.inc
          include /etc/firejail/disable-programs.inc
          include /etc/firejail/disable-devel.inc
          include /etc/firejail/disable-interpreters.inc

          # Allow development tools
          whitelist ''${HOME}/Development
          whitelist ''${HOME}/Downloads
          whitelist ''${HOME}/.ssh
          whitelist ''${HOME}/.gitconfig

          # Network restrictions
          netfilter
          nonewprivs
          nogroups

          # Filesystem restrictions
          private-dev
          private-tmp

          # Disable unnecessary features
          nodvd
          noprinters
          nosound
          notv
          nou2f
          novideo
        '';
      };
    };
  };

  # Darwin (macOS) system configuration
  flake.modules.darwin.virtualizationTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Install virtualization tools via Homebrew (better integration on macOS)
    homebrew = {
      brews = [
        "qemu" # QEMU virtualization
        "lima" # Linux VMs on macOS
        "vagrant" # Development environments
        "packer" # Machine image builder
        "wine-stable" # Windows compatibility
        "dosbox" # DOS emulator
        "scummvm" # Adventure game engine
      ];

      casks = [
        "vmware-fusion" # VMware hypervisor
        "parallels" # Parallels virtualization
        "utm" # QEMU frontend for macOS
        "virtualbox" # Oracle VirtualBox
        "docker" # Container platform (includes VM)
        "vagrant" # Vagrant GUI tools
        "wine-stable" # Wine GUI tools
        "crossover" # Commercial Wine distribution
        "dosbox-staging" # Modern DOS emulation
        "scummvm" # ScummVM with GUI
      ];

      taps = [
        "homebrew/cask-versions" # For multiple versions
        "lima-vm/tap" # Lima VM tools
      ];
    };

    # System packages for virtualization on macOS
    environment.systemPackages = with pkgs; [
      # Core virtualization utilities that work well via Nix on macOS
      packer # Machine image automation
      vagrant # Development environment management
      qemu-utils # QEMU disk utilities

      # Cross-platform emulation
      dosbox # DOS games and applications
      scummvm # Adventure game engine

      # Cloud and container tools
      cloud-init # Cloud VM initialization
      colima # Container runtime with VM backend

      # Remote access tools
      remmina # Multi-protocol remote desktop
      spice-gtk # SPICE display protocol
    ];

    # macOS-specific virtualization environment
    environment.variables = {
      # QEMU configuration
      QEMU_SYSTEM_PREFIX = "${pkgs.qemu}/bin/";

      # Lima VM configuration
      LIMA_HOME = "$HOME/.lima";

      # Vagrant provider preference
      VAGRANT_DEFAULT_PROVIDER = "vmware_desktop";

      # Wine configuration (if using Homebrew wine)
      WINEARCH = "win64";
      WINEPREFIX = "$HOME/.wine";
    };

    # Enable virtualization frameworks
    system.defaults = {
      # Enable hypervisor framework
      ".GlobalPreferences"."com.apple.security.virtualization" = true;
    };

    # Launch agents for virtualization services
    launchd.user.agents = {
      # Lima VM management (optional)
      lima-default = lib.mkIf false {
        # Disabled by default
        serviceConfig = {
          ProgramArguments = [
            "/opt/homebrew/bin/lima"
            "start"
            "default"
          ];
          RunAtLoad = true;
          KeepAlive = false;
          StandardOutPath = "/tmp/lima.out.log";
          StandardErrorPath = "/tmp/lima.err.log";
        };
      };

      # Colima container runtime (optional)
      colima-default = lib.mkIf false {
        # Disabled by default
        serviceConfig = {
          ProgramArguments = [
            "/opt/homebrew/bin/colima"
            "start"
            "--cpu"
            "2"
            "--memory"
            "4"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/tmp/colima.out.log";
          StandardErrorPath = "/tmp/colima.err.log";
        };
      };
    };

    # macOS security settings for virtualization
    security.pam.enableSudoTouchIdAuth = true; # For privileged VM operations

    # Networking configuration for VMs
    networking = {
      # Enable IP forwarding for VM networking
      forwarding = true;
    };
  };
}
