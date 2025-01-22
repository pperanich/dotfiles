{ pkgs, lib, inputs, outputs, config, ... }:
{
  system.stateVersion = 4;

  nix = {
    extraOptions = ''
      extra-platforms = x86_64-darwin aarch64-darwin
      '';
    linux-builder = {
      enable = true;
      ephemeral = true;
      maxJobs = 4;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      config = {
        virtualisation = {
          darwin-builder = {
            diskSize = 40 * 1024;
            memorySize = 8 * 1024;
          };
          cores = 6;
        };
      };
    };
  };

  nixpkgs = {
    config = {
      packageOverrides = _: {
        nixcasks = import inputs.nixcasks {
          inherit pkgs;
          osVersion = "sonoma";
        };
      };
    };
  };

  services = {
    nix-daemon.enable = true;
  };

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

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  homebrew = {
    enable = true;
  };
}
