{ config, ... }:
{
  # pperanich user configuration - both NixOS system user and home-manager setup
  flake.modules.nixos.pperanich =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # Create system user
      users.users.pperanich = {
        openssh.authorizedKeys.keys = [
          (builtins.readFile ./pperanich_id_ed25519.pub)
          (builtins.readFile ./peranpl1_id_ed25519.pub)
        ];
        shell = pkgs.zsh;
        packages = [ pkgs.home-manager ];
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
              inherit pkgs;
              inherit (config.flake.modules) homeManager;
            }
          )
        ];
      };
    };

  # Darwin system user configuration
  flake.modules.darwin.pperanich =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # Create system user
      users.users.pperanich = {
        openssh.authorizedKeys.keys = [
          (builtins.readFile ./pperanich_id_ed25519.pub)
          (builtins.readFile ./peranpl1_id_ed25519.pub)
        ];
        shell = pkgs.zsh;
        hashedPasswordFile = config.sops.secrets.pperanich-password.path;
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
          "audio"
          "dialout"
        ]
        ++ (builtins.filter (group: builtins.hasAttr group config.users.groups) [
          "network"
          "wireshark"
          "i2c"
          "mysql"
          "docker"
          "podman"
          "git"
        ]);
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
              inherit pkgs;
            }
          )
        ];
      };
    };
}
