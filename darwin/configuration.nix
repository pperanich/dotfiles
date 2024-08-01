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
    };
    envVars = { NIX_SSL_CERT_FILE = "/usr/local/share/ca-certificates/JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt"; };
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
    overlays = builtins.attrValues outputs.overlays;
    config = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
      allowUnfree = true;
      allowUnfreePredicate = _: true;
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

  homebrew = {
    enable = true;
  };
}
