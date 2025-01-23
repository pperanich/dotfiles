# Programming languages module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.home.features.development.languages;
in {
  imports = [
    ./rust.nix
    # ./python.nix
    # ./node.nix
    ./tex.nix
  ];

  options.modules.home.features.development.languages = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.modules.home.features.development.enable;
      description = "Whether to enable programming language support";
    };

    # Language-specific toggles with smart defaults
    rust = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable Rust development environment";
      };
    };

    # python = {
    #   enable = lib.mkOption {
    #     type = lib.types.bool;
    #     default = cfg.enable;
    #     description = "Whether to enable Python development environment";
    #   };
    # };

    # node = {
    #   enable = lib.mkOption {
    #     type = lib.types.bool;
    #     default = cfg.enable;
    #     description = "Whether to enable Node.js development environment";
    #   };
    # };

    tex = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable TeX/LaTeX environment";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Common language tools
    home.packages = with pkgs; [
      # Language servers
      nodePackages.typescript-language-server
      nodePackages.yaml-language-server
      nil # Nix
    ];
  };
}
