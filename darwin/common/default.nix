{ pkgs, lib, inputs, config, ...}:
{
  system.stateVersion = 4;

  services = {
    nix-daemon.enable = true;
    yabai = {
      enable = true;
      enableScriptingAddition = true;
      package = pkgs.yabai;
    };
    skhd = {
      enable = true;
      package = pkgs.skhd;
    };
    spacebar = {
      enable = true;
      package = pkgs.spacebar;
    };
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
      "com.apple.swipescrolldirection" = true;
    };
    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  users = {
    users.peranpl11 = {
      name = "peranpl1";
      shell = pkgs.zsh;
    };
  };

  home-manager = {
    users.peranpl1l = import "home-manager/peranpl1@peranpl1-ml1.nix";
    useGlobalPkgs = true;
  };
}
