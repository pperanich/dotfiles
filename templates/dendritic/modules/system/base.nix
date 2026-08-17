# The dendritic pattern in one file: one concern, exported to every platform
# that needs it. Machines then just list `base` in their imports.
{ inputs, ... }:
{
  flake.modules = {
    nixos.base =
      { pkgs, ... }:
      {
        imports = [
          inputs.home-manager.nixosModules.home-manager
        ];

        system.stateVersion = "26.05";
        home-manager.backupFileExtension = "hm-back";

        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        nixpkgs = {
          overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
          config.allowUnfree = true;
        };

        environment.systemPackages = with pkgs; [
          curl
          git
          vim
          wget
        ];

        services.openssh.enable = true;
      };

    darwin.base =
      { pkgs, ... }:
      {
        imports = [
          inputs.home-manager.darwinModules.home-manager
        ];

        system.stateVersion = 6;
        home-manager.backupFileExtension = "hm-back";

        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        nixpkgs = {
          overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
          config.allowUnfree = true;
        };

        environment.systemPackages = with pkgs; [
          curl
          git
          vim
        ];

        system.defaults = {
          dock.autohide = true;
          finder.AppleShowAllExtensions = true;
        };
      };

    homeManager.base =
      {
        config,
        pkgs,
        ...
      }:
      let
        homePrefix = if pkgs.stdenv.hostPlatform.isDarwin then "Users" else "home";
      in
      {
        programs = {
          home-manager.enable = true;
          direnv.enable = true;
          git.enable = true;
        };

        home = {
          stateVersion = "26.05";
          homeDirectory = "/${homePrefix}/${config.home.username}";

          sessionVariables = {
            EDITOR = "vim";
            PAGER = "less";
          };

          packages = with pkgs; [
            fd
            jq
            nil # Nix LSP
            nixfmt
            ripgrep
          ];
        };
      };
  };
}
