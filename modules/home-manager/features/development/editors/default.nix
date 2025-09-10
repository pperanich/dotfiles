# Development editors module
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.home.features.development.editors;
in {
  imports = [
    ./emacs.nix
    ./nvim.nix
    ./vscode.nix
  ];

  options.my.home.features.development.editors = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.my.home.features.development.enable;
      description = "Whether to enable development editors";
    };

    # Editor-specific toggles with smart defaults
    emacs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable Emacs editor";
      };
    };

    neovim = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable Neovim editor";
      };
    };

    vscode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable Visual Studio Code";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Common editor configuration
    home.sessionVariables = {
      EDITOR =
        if cfg.neovim.enable
        then "nvim"
        else if cfg.emacs.enable
        then "emacs -nw"
        else "vim";
    };

    # Common editor packages
    home.packages = with pkgs; [
      # Common dependencies
      ripgrep # Required for modern text search
      fd # Required for file finding
    ];
  };
}
