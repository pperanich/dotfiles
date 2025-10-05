_: {
  # peranpl1 user configuration - both NixOS system user and home-manager setup
  flake.modules.nixos.peranpl1 =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      # Create system user
      users.users.peranpl1 = {
        openssh.authorizedKeys.keys = [
          (builtins.readFile ./peranpl1_id_ed25519.pub)
          (builtins.readFile ./pperanich_id_ed25519.pub)
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
      nix.settings.trusted-users = [ "peranpl1" ];

      # Configure home-manager for this user
      home-manager = {
        useUserPackages = true;
        extraSpecialArgs = {
          inherit pkgs;
        };
        users.peranpl1.imports = lib.flatten [
          (
            _:
            import (lib.my.relativeToRoot "home-profiles/peranpl1") {
              inherit pkgs;
              inherit (config.flake.modules) homeManager;
            }
          )
        ];
      };
    };

  # Darwin system user configuration
  flake.modules.darwin.peranpl1 =
    {
      config,
      pkgs,
      lib,
      modules,
      ...
    }:
    {
      # Create system user
      users.users.peranpl1 = {
        openssh.authorizedKeys.keys = [
          (builtins.readFile ./peranpl1_id_ed25519.pub)
          (builtins.readFile ./pperanich_id_ed25519.pub)
        ];
        shell = pkgs.zsh;
        packages = [ pkgs.home-manager ];
        home = "/Users/peranpl1";
      };

      system.primaryUser = "peranpl1";

      launchd.user.envVariables = config.home-manager.users.peranpl1.home.sessionVariables;

      # Add to trusted users for nix
      nix.settings.trusted-users = [ "peranpl1" ];

      # Configure home-manager for this user
      home-manager = {
        useUserPackages = true;
        extraSpecialArgs = {
          inherit pkgs;
        };
        users.peranpl1.imports = lib.flatten [
          (
            _:
            import (lib.my.relativeToRoot "home-profiles/peranpl1") {
              inherit pkgs;
              inherit (modules) homeManager;
            }
          )
        ];
      };
    };
}
