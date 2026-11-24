{
  inputs,
  lib,
  modules,
  pkgs,
  ...
}:
let
  inherit (lib.my.homelab) rexWorker;
  workers = lib.attrValues rexWorker.users;
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

  users.users =
    lib.genAttrs workers (_: {
      isNormalUser = true;
      homeMode = "0700";
      linger = true;
      packages = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
        pkgs.git
        pkgs.ripgrep
      ];
    })
    // {
      sccache = {
        isSystemUser = true;
        group = "sccache";
      };
    };
  users.groups.sccache = { };
  services.rex.loginServer.accounts = lib.genAttrs workers (_: {
    principals = [ "tailscale:tag:nas" ];
  });
  # Interop sockets and drive mounts reach the Windows user; deny every worker both (docs/hermes.md).
  # Also provision the persistent host cache directory bind-mounted into CI containers.
  systemd.tmpfiles.rules =
    lib.concatMap (user: [
      "a+ /run/WSL - - - - u:${user}:---"
      "a+ /mnt - - - - u:${user}:---"
    ]) workers
    ++ [
      "d /var/cache/feedme-seed-corpus 0777 root root -"
    ];

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
    # 12C/24T with 31 GiB RAM: cap concurrent jobs at 4 (with 6 Cargo jobs each)
    # so parallel Rust/Android/Playwright builds stay within RAM and thermal budgets.
    capacity = 4;
    envs = {
      CARGO_BUILD_JOBS = "6";
      RUST_MIN_STACK = "16777216";
      # Shared host-backed WebDAV sccache endpoint on docker0 (only jobs with
      # sccache installed opt in via RUSTC_WRAPPER=sccache).
      SCCACHE_WEBDAV_ENDPOINT = "http://172.17.0.1:4227/";
    };
    # Expose host /dev/kvm (AMD-V via WSL2) for Android emulator tests and mount
    # a persistent host cache for the ~740 MB Google Drive seed corpus.
    # gitea-runner ignores `--device` unless `container.privileged` is enabled.
    containerPrivileged = true;
    containerOptions = "--device /dev/kvm --volume /var/cache/feedme-seed-corpus:/cache/feedme-seed-corpus";
    validVolumes = [ "/var/cache/feedme-seed-corpus" ];
  };

  # Local WebDAV cache backing sccache across concurrent CI job containers.
  # sccache's local disk backend only supports a single server process at a time,
  # so serving /var/cache/feedme-sccache over WebDAV bound strictly to docker0
  # gives concurrent containers race-free NVMe-backed crate caching with low RAM.
  systemd.services.sccache-webdav = {
    description = "Local WebDAV server for CI sccache";
    after = [
      "docker.service"
      "network.target"
    ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "sccache";
      Group = "sccache";
      CacheDirectory = "feedme-sccache";
      CacheDirectoryMode = "0755";
      ExecStart = "${pkgs.dufs}/bin/dufs --bind 172.17.0.1 --port 4227 --allow-all /var/cache/feedme-sccache";
      Restart = "on-failure";
      RestartSec = "2s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/cache/feedme-sccache" ];
    };
  };

  systemd.services.sccache-webdav-prune = {
    description = "Bound /var/cache/feedme-sccache disk usage";
    serviceConfig = {
      Type = "oneshot";
      User = "sccache";
      Group = "sccache";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/cache/feedme-sccache" ];
    };
    path = with pkgs; [
      coreutils
      findutils
    ];
    script = ''
      set -euo pipefail
      dir=/var/cache/feedme-sccache
      [ -d "$dir" ] || exit 0
      max_bytes=$((30 * 1024 * 1024 * 1024))
      target_bytes=$((25 * 1024 * 1024 * 1024))
      total=$(du -sb "$dir" | cut -f1)
      if [ "$total" -le "$max_bytes" ]; then
        exit 0
      fi
      while IFS=$'\t' read -r _atime size path; do
        [ -n "$path" ] || continue
        rm -f -- "$path"
        total=$((total - size))
        if [ "$total" -le "$target_bytes" ]; then
          break
        fi
      done < <(find "$dir" -type f -printf '%A@\t%s\t%p\n' | sort -n)
      find "$dir" -mindepth 1 -type d -empty -delete
    '';
  };

  systemd.timers.sccache-webdav-prune = {
    description = "Daily prune of /var/cache/feedme-sccache";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
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
    # Without a umask, drvfs shows every Windows file to every Linux user.
    wslConf.automount.options = "metadata,uid=1000,gid=100,umask=077";
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
