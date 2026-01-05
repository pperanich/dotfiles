# Centralized unfree package management
# Allows specific unfree packages by name across all configurations
{
  lib,
  config,
  ...
}: {
  # Define option for allowed unfree packages
  options.nixpkgs.allowedUnfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "List of unfree package names to allow";
    example = [ "vscode" "slack" "zoom" ];
  };

  # Apply allowlist to all configurations
  config.flake = {
    modules =
      let
        # Create predicate function to check if package is allowed
        predicate = pkg: builtins.elem (lib.getName pkg) config.nixpkgs.allowedUnfreePackages;
      in {
        # Apply to NixOS configurations
        nixos.base.nixpkgs.config.allowUnfreePredicate = predicate;

        # Apply to home-manager configurations
        homeManager.base = _args: {
          nixpkgs.config.allowUnfreePredicate = predicate;
        };

        # Optional: Apply to Darwin configurations
        # darwin.base.nixpkgs.config.allowUnfreePredicate = predicate;
      };

    # Export allowlist as flake metadata
    meta.nixpkgs.allowedUnfreePackages = config.nixpkgs.allowedUnfreePackages;
  };

  # Example usage in another module:
  # config.nixpkgs.allowedUnfreePackages = [ "vscode" "slack" ];
}
