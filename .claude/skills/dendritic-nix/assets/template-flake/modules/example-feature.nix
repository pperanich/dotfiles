# Example module showing the dendritic pattern with import-tree
# Modules export themselves by defining flake.modules.<platform>.<name>
_: {
  # home-manager module (user-level configuration)
  flake.modules.homeManager.example-feature = { pkgs, ... }: {
    home.packages = with pkgs; [
      # Add packages here
      hello
    ];

    home.sessionVariables = {
      EXAMPLE_VAR = "example-value";
    };
  };

  # NixOS module (system-level configuration)
  # Uncomment if you need NixOS-specific config
  # flake.modules.nixos.example-feature = { config, lib, pkgs, ... }: {
  #   environment.systemPackages = [ pkgs.example-package ];
  #   services.example-service.enable = true;
  # };

  # nix-darwin module (macOS system-level configuration)
  # Uncomment if you need Darwin-specific config
  # flake.modules.darwin.example-feature = { config, lib, pkgs, ... }: {
  #   environment.systemPackages = [ pkgs.example-package ];
  # };
}
