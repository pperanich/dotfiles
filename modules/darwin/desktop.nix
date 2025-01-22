{ config, lib, pkgs, ... }:

let
  cfg = config.my.darwin.desktop;
in
{
  options.my.darwin.desktop = {
    enable = lib.mkEnableOption "Darwin desktop configuration";
    
    yabai = {
      enable = lib.mkEnableOption "Yabai window manager";
      enableScriptingAddition = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable the scripting addition";
      };
    };

    skhd.enable = lib.mkEnableOption "SKHD hotkey daemon";
    sketchybar.enable = lib.mkEnableOption "Sketchybar status bar";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.yabai.enable {
      services.yabai = {
        enable = true;
        package = pkgs.yabai;
        enableScriptingAddition = cfg.yabai.enableScriptingAddition;
      };
    })

    (lib.mkIf cfg.skhd.enable {
      services.skhd.enable = true;
    })

    (lib.mkIf cfg.sketchybar.enable {
      services.sketchybar.enable = true;
    })

    (lib.mkIf cfg.enable {
      system.defaults = {
        dock = {
          autohide = true;
          mru-spaces = false;
          minimize-to-application = true;
        };
        
        NSGlobalDomain = {
          AppleShowAllExtensions = true;
          AppleShowScrollBars = "WhenScrolling";
          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
        };
      };
    })
  ];
} 