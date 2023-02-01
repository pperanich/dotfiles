{ pkgs, lib, inputs, outputs, config, ...}:
{
  system.stateVersion = 4;

  nix = {
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    settings = {
      trusted-users = [ "root" "peranpl1" ];
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      interval = { Day = 7; };
    };
  };

  services = {
    nix-daemon.enable = true;
  };

  # For spacebar debugging
  launchd.user.agents.spacebar.serviceConfig.StandardErrorPath = "/tmp/spacebar.err.log";
  launchd.user.agents.spacebar.serviceConfig.StandardOutPath = "/tmp/spacebar.out.log";
  # For yabai debugging
  launchd.user.agents.yabai.serviceConfig.StandardErrorPath = "/tmp/yabai.err.log";
  launchd.user.agents.yabai.serviceConfig.StandardOutPath = "/tmp/yabai.out.log";
  # For skhd debugging
  launchd.user.agents.skhd.serviceConfig.StandardErrorPath = "/tmp/skhd.err.log";
  launchd.user.agents.skhd.serviceConfig.StandardOutPath = "/tmp/skhd.out.log";

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

  programs.zsh.enable = true;
  users = {
    users.peranpl1 = {
      name = "peranpl1";
      home = "/Users/peranpl1";
      shell = pkgs.zsh;
    };
  };

  launchd.user.envVariables = outputs.homeConfigurations."peranpl1@peranpl1-ml1".config.home.sessionVariables;

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;
}
