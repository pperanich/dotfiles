{
  inputs,
  lib,
  modules,
  pkgs,
  ...
}:
let
  inherit (lib.my.homelab) rexWorker;
in
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-wsl.nixosModules.default
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base
    sops
    tailscale

    # User setup (headless — no desktop apps/fonts)
    pperanich

    # Development environment (minimal for WSL)
    rust
    aiTools

    # Offsite Google Drive Restic backup (docs/backups.md)
    backup

    # Gitea Actions runner (native dockerd inside WSL)
    giteaRunner
  ]);

  # WSL manages its own network; overrides the networkd defaults in modules/flake-parts/hosts.nix.
  networking.useNetworkd = false;
  systemd.network.wait-online.enable = true;

  my.pperanich = {
    desktop = false;
    passwordHashSecret = "passwords/pperanich";
  };
  users.mutableUsers = false;
  # NixOS-WSL turns the sudo password off by default; pperanich has one here.
  security.sudo.wheelNeedsPassword = true;

  # Rex sessions over the tailnet, for admin workstations and the phone
  my.rex.loginServer = {
    enable = true;
    inherit (rexWorker) port;
    principals = [
      "tailscale:tag:admin"
      "tailscale:tag:mobile"
    ];
  };

  users.users.${rexWorker.user} = {
    isNormalUser = true;
    homeMode = "0700";
    linger = true;
    packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex ];
  };
  services.rex.loginServer.accounts.${rexWorker.user}.principals = [ "tailscale:tag:nas" ];

  # No node exporter here, so Healthchecks.io is what notices a failed or missing run.
  my.backup.googleDrive = {
    enable = true;
    passwordSecret = "restic-gdrive-password";
    rcloneConfigSecret = "rclone-gdrive-conf";
    healthchecksPingUrlSecret = "healthchecks-gdrive-ping-url";
    metricsDir = null;
    paths = [ "/home/pperanich" ];
    # Caches, toolchains and build output: about 60 of the home's 90 GB, all rebuildable.
    exclude =
      map (dir: "/home/pperanich/${dir}") [
        ".cache"
        "micromamba"
        ".npm"
        ".npm-global"
        ".rustup"
        ".cargo"
        "go"
        ".vscode-server"
        ".windsurf-server"
      ]
      # Most Rust target/ dirs carry CACHEDIR.TAG (skipped by --exclude-caches); cargo-leptos
      # builds do not, and a bare "target" would hit kernel and Zephyr source folders.
      ++ [
        "target/debug"
        "target/release"
        "target/front"
        "node_modules"
        ".venv"
        ".direnv"
      ];
  };

  my.giteaRunner = {
    enable = true;
    url = "https://gitea.prestonperanich.com";
    tokenSecret = "gitea-runner-token";
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  environment.systemPackages = with pkgs; [
    stdenv
    f2fs-tools
  ];

  wsl = {
    enable = true;
    defaultUser = "pperanich";
    # Native dockerd (enabled by giteaRunner) replaces the Docker Desktop integration.
    docker-desktop.enable = false;
    interop.register = true;
    startMenuLaunchers = true;
    usbip.enable = true;
    wslConf.network.generateHosts = false;
    wslConf.network.generateResolvConf = true;
  };

  networking = {
    hostName = "pp-wsl1";
    # WSL generates /etc/resolv.conf (wslConf.network.generateResolvConf);
    # 26.05 asserts resolvconf must be off when something else owns the file.
    resolvconf.enable = false;
    interfaces = {
      # eth0 = {
      #   useDHCP = true;
      #   wakeOnLan.enable = true;
      # };
      # eth1 = {
      #   useDHCP = true;
      #   wakeOnLan.enable = true;
      # };
      # eth2 = {
      #   useDHCP = true;
      #   wakeOnLan.enable = true;
      # };
      # eth3 = {
      #   useDHCP = true;
      #   wakeOnLan.enable = true;
      # };
    };
  };

  programs = {
    dconf.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    config.shared.default = "*";
  };

  # services.resolved.enable = false;
}
