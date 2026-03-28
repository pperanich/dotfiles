# Unified Nix configuration module for all platforms
{ inputs, ... }:
{
  flake.modules = {
    # NixOS Nix configuration
    nixos.base =
      {
        pkgs,
        options,
        ...
      }:
      {
        imports = [
          inputs.home-manager.nixosModules.home-manager
          inputs.nix-index-database.nixosModules.nix-index
          inputs.determinate.nixosModules.default
          inputs.nix-ld.nixosModules.nix-ld
        ];

        system.stateVersion = "25.11";

        # Disable NixOS manual/options doc generation to avoid builtins.toFile warning
        # (options.json references store paths without proper context)
        documentation.nixos.enable = false;
        documentation.nixos.options.splitBuild = false;

        home-manager.backupFileExtension = "hm-back";

        environment.systemPackages = with pkgs; [
          ghostty.terminfo
          # Merged from former file-exploration + networkUtilities modules
          openssh
          fzf
          curl
          wget
          bandwhich
        ];

        nixpkgs = {
          overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
            allowBroken = true;
          };
        };

        nix.settings = {
          extra-substituters = [ "https://nix-community.cachix.org" ];
          extra-trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
        };

        programs.nix-ld.dev = {
          enable = true;
          libraries =
            options.programs.nix-ld.dev.libraries.default
            ++ (with pkgs; [
              dbus # libdbus-1.so.3
              fontconfig # libfontconfig.so.1
              freetype # libfreetype.so.6
              glib # libglib-2.0.so.0
              libGL # libGL.so.1
              libxkbcommon # libxkbcommon.so.0
              libX11 # libX11.so.6
              wayland
            ]);

        };
      };

    # Darwin Nix configuration
    darwin.base =
      {
        pkgs,
        ...
      }:
      {
        imports = [
          inputs.home-manager.darwinModules.home-manager
          inputs.nix-index-database.darwinModules.nix-index
          inputs.determinate.darwinModules.default
        ];
        system.stateVersion = 6;

        # We are using the Determinate daemon
        nix.enable = false;
        # Custom settings written to /etc/nix/nix.custom.conf
        determinateNix = {
          enable = true;
          customSettings = {
            eval-cores = 0;
            extra-experimental-features = "external-builders parallel-eval";
            # extra-substituters = "nix-apple-fonts.cachix.org";
            # extra-trusted-public-keys = "nix-apple-fonts.cachix.org-1:+IufU9qEralI2eCib9vH4bv093Xo1F9l0rw24KzLEdg=";
          };
        };

        programs.zsh.enableCompletion = false;
        programs.zsh.enableBashCompletion = false;

        system.defaults = {
          spaces.spans-displays = false;
          # universalaccess.reduceMotion = true;
          dock = {
            autohide = true;
            showhidden = true;
            mru-spaces = false;
            launchanim = false;
            persistent-apps = [
              # Workspace 1: Term
              "/Applications/Ghostty.app"
              # Workspace 2: Web
              "/Applications/Brave Browser.app"
              # Workspace 3: Notes
              "/Applications/Obsidian.app"
              "/System/Applications/Notes.app"
              # Workspace 4: IDE
              "/Applications/Visual Studio Code.app"
              # Workspace 5: Comms
              # "/Applications/Slack.app"
              # "/Applications/Microsoft Outlook.app"
              # "/Applications/zoom.us.app"
              # Workspace 6: Creative
              "/Applications/GIMP.app"
              "/Applications/Blender.app"
              # "/Applications/REAPER.app"
              # Workspace 7: Social
              "/System/Applications/Messages.app"
              "/Applications/Discord.app"
              "/Applications/Element.app"
              # Utils
              "/System/Applications/System Settings.app"
            ];
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
        services.openssh.enable = true;
        homebrew = {
          enable = true;
          greedyCasks = true;
          taps = [
            "nikitabobko/tap"
          ];
          brews = [
            "xcode-build-server"
            "xcbeautify"
            "xcp"
            "opencode"
            "uv"
            "docker"
            "docker-compose"
            "docker-credential-helper"
          ];
          casks = [
            "slack"
            "ghostty"
            "discord"
            "element"
            "visual-studio-code"
            "claude"
            "claude-code"
            "reaper"
            "google-chrome"
            "brave-browser"
            "blender"
            "gimp"
            "xquartz"
            "obsidian"
            "aerospace"
            "leader-key"
          ];
          onActivation = {
            autoUpdate = true;
            upgrade = true;
          };
        };

        environment.systemPackages = with pkgs; [
          openssh
          # python313Packages.pymobiledevice3
        ];

        nixpkgs = {
          overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
            allowBroken = true;
          };
        };
      };

    # Home Manager Nix configuration
    homeManager.base =
      {
        lib,
        pkgs,
        config,
        ...
      }:
      let
        homePrefix = if pkgs.stdenv.hostPlatform.isDarwin then "Users" else "home";
      in
      {
        imports = [
          inputs.nix-index-database.homeModules.nix-index
        ];
        # User-level Nix configuration via Home Manager
        # Note: This configures the user's environment, not the system daemon
        manual.manpages.enable = false;

        xdg.enable = true;

        # Default programs
        programs = {
          home-manager.enable = true;
          pandoc.enable = true;
          gpg.enable = true;
          dircolors.enable = true;
          direnv.enable = true;
          atuin = {
            enable = true;
            daemon.enable = true;
          };
          zoxide.enable = true;
          nix-index-database.comma.enable = true;
          vscode.enable = true;
        };

        # Configure user nixpkgs
        nixpkgs = {
          overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
            allowBroken = true;
          };
        };

        home = {
          # User session variables
          sessionVariables = {
            FLAKE = "${config.home.homeDirectory}/dotfiles/";
            SHELL = "${pkgs.zsh}/bin/zsh";
            LANG = "en_US.UTF-8";
            LC_ALL = "en_US.UTF-8";
            EDITOR = "nvim";
            VISUAL = "nvim";
            PAGER = "less";
            MANPAGER = "less -R --use-color -Dd+r -Du+b";
          };
          enableNixpkgsReleaseCheck = false;
          stateVersion = "25.11";
          homeDirectory = "/${homePrefix}/${config.home.username}";

          activation = {
            stowHome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              DOTFILES_DIR="${config.home.homeDirectory}/dotfiles"
              if [ ! -d "$DOTFILES_DIR" ]; then
                echo "Cloning dotfiles repo to $DOTFILES_DIR..."
                ${pkgs.git}/bin/git clone git@github.com:pperanich/dotfiles.git "$DOTFILES_DIR"
              fi
              pushd "$DOTFILES_DIR" >/dev/null
              ${pkgs.stow}/bin/stow home
              popd >/dev/null
            '';
          };

          # User-level packages that enhance Nix experience
          packages = with pkgs; [
            # Nix development tools
            nil # Nix LSP
            nixfmt # Nix formatter
            nix-tree # Explore Nix store dependencies
            nix-diff # Compare Nix derivations

            # Development environment tools
            devenv # Developer environments with Nix
          ];
        };
      };
  };
}
