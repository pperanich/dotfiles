_:
let
  sopsFolder = ../../sops;
in
{
  # pperanich user configuration - both NixOS system user and home-manager setup
  flake.modules.nixos.pperanich =
    {
      config,
      lib,
      pkgs,
      modules,
      ...
    }:
    {
      options.my.pperanich.desktop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to include desktop applications and fonts in pperanich's home environment";
      };

      config = {
        # Deploy SSH private key via system-level sops BEFORE home-manager runs
        # This breaks the chicken-and-egg: home-manager sops needs SSH key to decrypt,
        # but SSH key is a secret. System sops uses machine key, so it can decrypt first.
        sops.secrets."private_keys/pperanich" = {
          sopsFile = "${sopsFolder}/secrets.yaml";
          owner = "pperanich";
          group = "users";
          mode = "0400";
          path = "/home/pperanich/.ssh/id_ed25519";
        };

        # Create system user
        users.users.pperanich = {
          openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
          shell = pkgs.zsh;
          packages = [ pkgs.home-manager ];
          # Add to keys group for reading machine's sops age key
          extraGroups = [ "keys" ];
        };

        # Enable zsh system-wide
        programs.zsh = {
          enable = true;
          enableCompletion = false;
        };

        # Add to trusted users for nix
        nix.settings.trusted-users = [ "pperanich" ];

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
                inherit (config.my.pperanich) desktop;
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
    {
      # Deploy SSH private key via system-level sops BEFORE home-manager runs
      sops.secrets."private_keys/pperanich" = {
        sopsFile = "${sopsFolder}/secrets.yaml";
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

      # Add to trusted users for nix
      nix.settings.trusted-users = [ "pperanich" ];

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
            }
          )
        ];
      };
    };
}
