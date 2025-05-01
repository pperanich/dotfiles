# Core module for shared configuration across all systems
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.core;
in {
  imports = lib.flatten [
    (lib.my.relativeToRoot "modules/shared/core")
    inputs.mac-app-util.darwinModules.default
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops
  ];

  config = lib.mkIf cfg.enable {
    system.stateVersion = 5;

    # We are using the Determinate daemon
    nix.enable = false;

    system.defaults = {
      dock = {
        autohide = true;
        showhidden = true;
        mru-spaces = false;
        launchanim = false;
      };
      finder = {
        AppleShowAllExtensions = true;
        QuitMenuItem = true;
      };
      NSGlobalDomain = {
        AppleKeyboardUIMode = 3;
        ApplePressAndHoldEnabled = false;
        AppleFontSmoothing = 1;
        _HIHideMenuBar = true;
        InitialKeyRepeat = 10;
        KeyRepeat = 1;
        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.swipescrolldirection" = false;
      };
      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = false;
      };
    };

    security.pam.services.sudo_local = {
      enable = true;
      touchIdAuth = true;
      reattach = true;
    };
    homebrew.enable = true;

    home-manager.sharedModules = [
      inputs.mac-app-util.homeManagerModules.default
    ];

    nixpkgs = {
      config = {
        packageOverrides = _: {
          nixcasks = import inputs.nixcasks {
            inherit pkgs;
            osVersion = "sequoia";
          };
        };
      };
    };

  };
}
