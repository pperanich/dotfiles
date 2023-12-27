{ pkgs, lib, inputs, outputs, config, ... }:
{
  #imports = [
  #  ../modules/darwin/sketchybar
  #];
  system.stateVersion = 4;

  nix = {
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    settings = {
      trusted-users = [ "root" "peranpl1" ];
      # Enable flakes and new 'nix' command
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      warn-dirty = false;
      # Deduplicate and optimize nix store
      # auto-optimise-store = true;
    };
    # gc = {
    #   automatic = true;
    #   interval = { Day = 7; };
    # };
    envVars = { NIX_SSL_CERT_FILE = "/etc/ssl/certs/JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt"; };
  };

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
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

  programs.zsh.enable = true;
  users = {
    users.peranpl1 = {
      name = "peranpl1";
      home = "/Users/peranpl1";
      shell = pkgs.zsh;
    };
  };

  launchd.user.envVariables = config.home-manager.users.peranpl1.home.sessionVariables;

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "Iosevka" "JetBrainsMono" ]; })
    ];
  };
}
