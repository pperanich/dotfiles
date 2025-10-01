{
  inputs,
  outputs,
  ...
}:
{
  # peranpl1 user configuration - both NixOS system user and home-manager setup
  flake.modules.nixos.peranpl1 =
    {
      pkgs,
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

      # Configure home-manager for this user (simplified)
      home-manager = {
        useUserPackages = true;
        users.peranpl1 = {
          # Basic user configuration - detailed setup via home modules
          home.stateVersion = "25.05";
          home.username = "peranpl1";
          home.homeDirectory = "/home/peranpl1";
        };
      };
    };

  # Darwin system user configuration
  flake.modules.darwin.peranpl1 =
    {
      config,
      pkgs,
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

      # Enable zsh system-wide
      programs.zsh = {
        enable = true;
        enableCompletion = false;
      };

      # Add to trusted users for nix
      nix.settings.trusted-users = [ "peranpl1" ];

      # Configure home-manager for this user (simplified)
      home-manager = {
        useUserPackages = true;
        extraSpecialArgs = {
          inherit pkgs inputs outputs;
        };
        users.peranpl1 = {
          # Basic user configuration - detailed setup via home modules
          home.stateVersion = "25.05";
          home.username = "peranpl1";
          home.homeDirectory = "/Users/peranpl1";
        };
      };
    };

  flake.modules.homeManager.peranpl1 =
    {
      pkgs,
      self,
      ...
    }:
    {
      homeConfigurations = {
        peranpl1 = inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs; };
          modules = with self.flake.modules.homeManager; [
            # Core system configuration
            base

            # Desktop environment
            fonts
            desktopApplications
            zsh

            # Development environment
            nvim
            vscode
            rust

            # Network and file utilities
            networkUtilities
            fileExploration

            # Work environment
            aplnis
          ];
        };
      };
    };
}
