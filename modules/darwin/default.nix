# Add your reusable Darwin modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.

{
  # List your module files here
  # my-module = import ./my-module.nix;
}

{ config, lib, pkgs, ... }:

let
  cfg = config.my.darwin;
in
{
  imports = [
    ./wm/yabai.nix
    ./wm/skhd.nix
    ./wm/sketchybar.nix
  ];

  options.my.darwin = {
    enable = lib.mkEnableOption "Darwin-specific configuration";

    dock = {
      enable = lib.mkEnableOption "dock configuration";
      autohide = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to automatically hide the dock";
      };
      orientation = lib.mkOption {
        type = lib.types.enum [ "bottom" "left" "right" ];
        default = "bottom";
        description = "Dock orientation";
      };
    };

    keyboard = {
      enable = lib.mkEnableOption "keyboard configuration";
      inititalKeyRepeat = lib.mkOption {
        type = lib.types.int;
        default = 15;
        description = "Initial key repeat delay";
      };
      keyRepeat = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Key repeat interval";
      };
    };

    trackpad = {
      enable = lib.mkEnableOption "trackpad configuration";
      naturalScrolling = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable natural scrolling direction";
      };
      tapToClick = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable tap to click";
      };
    };

    windowManager = {
      yabai.enable = lib.mkEnableOption "Yabai window manager";
      skhd.enable = lib.mkEnableOption "SKHD hotkey daemon";
      sketchybar.enable = lib.mkEnableOption "Sketchybar status bar";
    };

    apps = {
      enable = lib.mkEnableOption "macOS apps configuration";
      installApps = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install macOS apps via Homebrew Cask";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    system = {
      defaults = {
        dock = lib.mkIf cfg.dock.enable {
          autohide = cfg.dock.autohide;
          orientation = cfg.dock.orientation;
          showhidden = true;
          mru-spaces = false;
          minimize-to-application = true;
          show-recents = false;
          static-only = true;
        };

        trackpad = lib.mkIf cfg.trackpad.enable {
          Clicking = cfg.trackpad.tapToClick;
          TrackpadRightClick = true;
          TrackpadThreeFingerDrag = true;
          Natural = cfg.trackpad.naturalScrolling;
          ActuationStrength = 1; # Firm click pressure
          FirstClickThreshold = 1;
          SecondClickThreshold = 1;
        };

        NSGlobalDomain = lib.mkMerge [
          (lib.mkIf cfg.keyboard.enable {
            InitialKeyRepeat = cfg.keyboard.inititalKeyRepeat;
            KeyRepeat = cfg.keyboard.keyRepeat;
          })
          {
            AppleShowAllExtensions = true;
            AppleKeyboardUIMode = 3;
            ApplePressAndHoldEnabled = false;
            NSAutomaticCapitalizationEnabled = false;
            NSAutomaticDashSubstitutionEnabled = false;
            NSAutomaticPeriodSubstitutionEnabled = false;
            NSAutomaticQuoteSubstitutionEnabled = false;
            NSAutomaticSpellingCorrectionEnabled = false;
            NSNavPanelExpandedStateForSaveMode = true;
            NSNavPanelExpandedStateForSaveMode2 = true;
            NSScrollAnimationEnabled = true;
            PMPrintingExpandedStateForPrint = true;
            PMPrintingExpandedStateForPrint2 = true;
          }
        ];

        finder = {
          AppleShowAllExtensions = true;
          QuitMenuItem = true;
          FXEnableExtensionChangeWarning = false;
          CreateDesktop = false; # Hide desktop icons
          ShowPathbar = true;
          ShowStatusBar = true;
          _FXShowPosixPathInTitle = true; # Show full path in title
        };

        # Additional system settings
        menuExtraClock = {
          Show24Hour = true;
          ShowDate = 0;
          ShowDayOfWeek = true;
        };

        screencapture = {
          location = "~/Desktop/Screenshots";
          type = "png";
        };
      };

      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
      };

      activationScripts.postActivation.text = ''
        # Dock settings
        defaults write com.apple.dock autohide-delay -float 0
        defaults write com.apple.dock autohide-time-modifier -float 0.5
        
        # Finder settings
        defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
        defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
        defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
        defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
        
        # Kill affected applications
        for app in "Dock" "Finder"; do
          killall "$app" > /dev/null 2>&1 || true
        done
      '';
    };

    # Homebrew configuration
    homebrew = lib.mkMerge [
      {
        enable = true;
        onActivation = {
          autoUpdate = true;
          cleanup = "zap";
          upgrade = true;
        };
        taps = [
          "homebrew/cask-fonts"
          "homebrew/services"
          "homebrew/cask-versions"
        ];
        brews = [
          "mas" # Mac App Store CLI
        ];
        casks = [
          "font-fira-code"
          "font-jetbrains-mono"
          "font-jetbrains-mono-nerd-font"
        ];
      }
      (lib.mkIf (cfg.apps.enable && cfg.apps.installApps) {
        casks = [
          # Browsers
          "firefox"
          "google-chrome"
          
          # Development
          "visual-studio-code"
          "iterm2"
          "docker"
          
          # Utilities
          "rectangle"
          "alfred"
          "1password"
          
          # Communication
          "slack"
          "zoom"
          
          # Media
          "spotify"
          "vlc"
        ];
      })
    ];
  };
}
