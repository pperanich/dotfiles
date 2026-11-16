_: {
  # pperanich user configuration - both NixOS system user and home-manager setup
  flake.modules.nixos.pperanich =
    {
      config,
      lib,
      pkgs,
      modules,
      ...
    }:
    let
      cfg = config.my.pperanich;
    in
    {
      imports = [ modules.nixos.rex ];

      options.my.pperanich = {
        desktop = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to include desktop applications and fonts in pperanich's home environment";
        };

        deploySshPrivateKey = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Deploy private_keys/pperanich to ~/.ssh/id_ed25519 via system sops. Off: each workstation keeps its own key on disk.";
        };

        passwordHashSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "passwords/pperanich";
          description = "Optional sops secret name containing mkpasswd -m yescrypt/sha-512 hash for interactive sudo.";
        };

        trustedNixUser = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Grant nix.settings.trusted-users to pperanich. A trusted Nix user is root-equivalent on the host.";
        };
      };

      config = {
        my.desktop.enable = lib.mkDefault cfg.desktop;

        # Deploy SSH private key via system-level sops BEFORE home-manager runs
        # on physical desktop workstations only (never headless servers or WSL).
        # Follows sops.defaultSopsFile so downstream/per-host files override cleanly.
        sops.secrets = lib.mkMerge [
          (lib.mkIf cfg.deploySshPrivateKey {
            "private_keys/pperanich" = {
              owner = "pperanich";
              group = "users";
              mode = "0400";
              path = "/home/pperanich/.ssh/id_ed25519";
            };
          })
          (lib.mkIf (cfg.passwordHashSecret != null) {
            ${cfg.passwordHashSecret}.neededForUsers = true;
          })
        ];

        # Create system user
        users.users.pperanich = {
          isNormalUser = true;
          openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
          hashedPasswordFile = lib.mkIf (
            cfg.passwordHashSecret != null
          ) config.sops.secrets.${cfg.passwordHashSecret}.path;
          shell = pkgs.zsh;
          packages = [ pkgs.home-manager ];
          # Keeps /run/user/<uid> after logout, where the Rex server and its sessions live.
          linger = true;
          extraGroups = [
            "wheel"
          ]
          ++ lib.optionals cfg.desktop [
            "video"
            "audio"
            "networkmanager"
          ];
        };

        # Enable zsh system-wide
        programs.zsh = {
          enable = true;
          enableCompletion = false;
        };

        nix.settings.trusted-users = lib.mkIf cfg.trustedNixUser [ "pperanich" ];

        # Read only where a host turns on my.rex.loginServer: admin workstations
        # get this account's Rex server without a password or key.
        services.rex.loginServer.accounts.pperanich.principals = [ "tailscale:tag:admin" ];

        # Configure home-manager for this user
        home-manager = {
          useUserPackages = true;
          extraSpecialArgs = {
            inherit pkgs;
          };
          users.pperanich.imports = lib.flatten [
            (
              _:
              import (lib.my.relativeToRoot "home-profiles/pperanich") {
                inherit (modules) homeManager;
                inherit lib;
                config = config.home-manager.users.pperanich;
                inherit (cfg) desktop;
              }
            )
          ];
        };
      };
    };

  # Darwin system user configuration
  flake.modules.darwin.pperanich =
    {
      config,
      lib,
      pkgs,
      modules,
      ...
    }:
    let
      cfg = config.my.pperanich;
    in
    {
      imports = [ modules.darwin.rex ];

      options.my.pperanich = {
        desktop = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to include desktop applications and fonts in pperanich's home environment";
        };

        deploySshPrivateKey = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Deploy private_keys/pperanich to ~/.ssh/id_ed25519 via system sops. Off: each workstation keeps its own key on disk.";
        };

        trustedNixUser = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Grant nix.settings.trusted-users to pperanich. A trusted Nix user is root-equivalent on the host.";
        };
      };

      config = {
        my.desktop.enable = lib.mkDefault cfg.desktop;

        # Deploy SSH private key via system-level sops BEFORE home-manager runs.
        # Follows sops.defaultSopsFile so downstream/per-host files override cleanly.
        sops.secrets."private_keys/pperanich" = lib.mkIf cfg.deploySshPrivateKey {
          owner = "pperanich";
          group = "staff";
          mode = "0400";
          path = "/Users/pperanich/.ssh/id_ed25519";
        };

        # Create system user
        users.users.pperanich = {
          openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
          shell = pkgs.zsh;
          packages = [ pkgs.home-manager ];
          home = "/Users/pperanich";
        };

        system.primaryUser = "pperanich";

        # zim's completion module owns compinit; skip nix-darwin's global compinit
        # in /etc/zshrc to avoid the "completion was already initialized" warning.
        programs.zsh.enableGlobalCompInit = false;

        launchd.user.envVariables = config.home-manager.users.pperanich.home.sessionVariables;

        # Determinate owns nix.conf on darwin (nix.enable = false), so nix.settings is never written.
        determinateNix.customSettings.trusted-users = lib.mkIf cfg.trustedNixUser [
          "root"
          "pperanich"
        ];

        # Configure home-manager for this user
        home-manager = {
          useUserPackages = true;
          extraSpecialArgs = {
            inherit pkgs;
          };
          users.pperanich.imports = lib.flatten [
            (
              _:
              import (lib.my.relativeToRoot "home-profiles/pperanich") {
                inherit (modules) homeManager;
                inherit lib;
                config = config.home-manager.users.pperanich;
                inherit (cfg) desktop;
              }
            )
          ];
        };
      };
    };
}
