{ config, lib, pkgs, ... }:

let
  cfg = config.my.user;
in
{
  options.my.user = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "The name of the primary user account";
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      description = "The full name of the primary user";
    };

    email = lib.mkOption {
      type = lib.types.str;
      description = "The email of the primary user";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional groups for the primary user";
    };

    shell = lib.mkOption {
      type = lib.types.package;
      default = pkgs.zsh;
      description = "The shell for the primary user";
    };
  };

  config = {
    # Create the user account
    users.users.${cfg.name} = {
      inherit (cfg) shell;
      isNormalUser = true;
      description = cfg.fullName;
      extraGroups = [ "wheel" "networkmanager" ] ++ cfg.extraGroups;
      
      # For Darwin systems
      home = if pkgs.stdenv.isDarwin
        then "/Users/${cfg.name}"
        else "/home/${cfg.name}";
    };

    # Set default shell system-wide if it's zsh
    programs.zsh.enable = cfg.shell == pkgs.zsh;

    # Environment variables
    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
    };
  };
} 