# Container development CLI tools and user environment
# Provides packages, aliases, and environment for all platforms
_: {
  # Home Manager user configuration
  flake.modules.homeModules.containerDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # Container runtime tools (for when not managed by system)
        podman
        qemu
        gvproxy

        # Container development tools
        docker-compose
        lazydocker
        dive # Explore container image layers

        # Kubernetes tools
        kubectl
        kubectx
        kustomize

        # Container registry tools
        crane
        regctl

        # Development utilities
        ctop # Container process monitoring
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific container tools
        podman-tui
        containers-toolbox
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific tools handled via homebrew in darwin module
      ];

    # Container development environment configuration
    home.sessionVariables = {
      # Set default container registry
      REGISTRY = lib.mkDefault "docker.io";

      # Podman specific environment
      DOCKER_HOST = lib.mkIf pkgs.stdenv.hostPlatform.isLinux "unix:///run/user/$(id -u)/podman/podman.sock";
    };

    # Shell aliases for container development
    home.shellAliases = {
      # Unified container commands (works with podman docker-compat)
      dps = "docker ps";
      dimg = "docker images";
      dlogs = "docker logs";
      dexec = "docker exec -it";

      # Container cleanup
      docker-cleanup = "docker system prune -f";
      docker-cleanup-all = "docker system prune -af";

      # Development shortcuts
      dc = "docker-compose";
      dcu = "docker-compose up";
      dcd = "docker-compose down";
      dcl = "docker-compose logs -f";
    };

    # Git configuration for container-related development
    programs.git.extraConfig = {
      # Container-friendly line endings
      core.autocrlf = false;
    };

    # VSCode extensions for container development (if VSCode is enabled)
    programs.vscode.extensions = lib.mkIf (config.programs.vscode.enable or false) (with pkgs.vscode-extensions; [
      ms-vscode-remote.remote-containers
      ms-azuretools.vscode-docker
    ]);
  };

  # Darwin (macOS) system configuration
  flake.modules.darwin.containerDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Install container tools via Homebrew (better integration on macOS)
    homebrew = {
      brews = [
        "podman"
        "docker-compose"
      ];

      casks = [
        "podman-desktop"
        "docker" # Docker Desktop as alternative
      ];
    };

    # System packages for container development on macOS
    environment.systemPackages = with pkgs; [
      # Container utilities that work well via Nix on macOS
      kubectl
      dive
      lazydocker
      skopeo
      crane
    ];

    # macOS-specific container environment
    environment.variables = {
      # Default to rootless podman
      DOCKER_HOST = "unix:///Users/$(whoami)/.local/share/containers/podman/machine/podman.sock";
    };

    # Launch agents for container services (if needed)
    launchd.user.agents = lib.mkIf false {
      # Disabled by default
      podman-machine = {
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.podman}/bin/podman"
            "machine"
            "start"
          ];
          RunAtLoad = true;
          KeepAlive = false;
        };
      };
    };
  };

  # NixOS system configuration (tools only)
  flake.modules.nixos.containerDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.containers;
  in {
    # System packages for container development
    environment.systemPackages = with pkgs;
      [
        # Container compose tools
        (
          if cfg.runtime == "podman"
          then podman-compose
          else docker-compose
        )

        # Container management utilities
        buildah
        skopeo

        # Additional user-specified packages
      ]
      ++ cfg.extraPackages;
  };
}
