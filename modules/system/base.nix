# Unified Nix configuration module for all platforms
{ inputs, ... }:
{
  flake.modules = {
    # NixOS Nix configuration
    nixos.base =
      {
        config,
        lib,
        pkgs,
        options,
        ...
      }:
      {
        imports = [
          inputs.home-manager.nixosModules.home-manager
          inputs.nix-index-database.nixosModules.nix-index
          inputs.determinate.nixosModules.default
        ];

        options.my.desktop.enable = lib.mkEnableOption "desktop workstation profile (GUI applications and roaming workstation defaults)";

        config = {
          system.stateVersion = "26.05";

          # Disable NixOS manual/options doc generation to avoid builtins.toFile warning
          # (options.json references store paths without proper context)
          documentation.nixos.enable = false;
          documentation.nixos.options.splitBuild = false;

          home-manager.backupFileExtension = "hm-back";

          # Resolve bare fleet hostnames via the router's DNS; tailnet
          # connections use explicit *.pp-ts names instead.
          networking.search = [ "home.arpa" ];

          # With systemd-resolved, the global search domains above also become
          # routing domains; resolved's compiled-in fallback (Cloudflare/Google)
          # would then answer *.home.arpa with NXDOMAIN. No fallback → queries
          # fall through to the LAN link's DHCP-provided DNS instead.
          services.resolved.settings.Resolve.FallbackDNS = [ ];

          # networkd ignores DHCP/RA-provided search domains (option 119 / DNSSL)
          # unless UseDomains is set; without a per-link domain, resolved won't
          # expand bare fleet hostnames
          systemd.network.config = {
            dhcpV4Config.UseDomains = true;
            dhcpV6Config.UseDomains = true;
          };

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
              permittedInsecurePackages =
                lib.optionals config.my.desktop.enable [
                  # TODO: drop once nixos-26.05 bumps bitwarden-desktop off EOL electron 39
                  "electron-39.8.10"
                ]
                ++ lib.optionals (config.services.immich.enable or false) [
                  # TODO: drop at the 26.11 bump (Immich 3). 26.05 only ships 2.7.5, which
                  # is end-of-life and flagged for CVE-2026-59258 / CVE-2026-82272.
                  # Scoped strictly to hosts enabling services.immich (pp-nas1).
                  "immich-2.7.5"
                ];
            };
          };

          nix.settings = {
            extra-substituters = [ "https://nix-community.cachix.org" ];
            extra-trusted-public-keys = [
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];
          };

          programs.nh.enable = true;

          # sudo prints its "usual lecture" the first time an account is asked for a password.
          security.sudo.extraConfig = "Defaults lecture = never";

          programs.ssh.knownHosts = lib.my.mkKnownHosts lib.my.sshHostKeys;

          programs.nix-ld = {
            enable = true;
            libraries =
              options.programs.nix-ld.libraries.default
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
      };

    # Darwin Nix configuration
    darwin.base =
      {
        lib,
        pkgs,
        ...
      }:
      {
        imports = [
          inputs.home-manager.darwinModules.home-manager
          inputs.nix-index-database.darwinModules.nix-index
          inputs.determinate.darwinModules.default
        ];

        options.my.desktop.enable = lib.mkEnableOption "desktop workstation profile (GUI applications and roaming workstation defaults)";

        config = {
          # Determinate's NixOS module substitutes from here already; on darwin it is only
          # trusted, so Determinate Nix itself compiled locally. Its keys are already trusted.
          determinateNix.customSettings.extra-substituters = [ "https://install.determinate.systems" ];

          system = {
            stateVersion = 6;

            # Per-power-source sleep policy (nix-darwin's power.sleep.* is global
            # via systemsetup, so use pmset directly): sleep on battery, stay
            # awake with wake-on-LAN on AC. Reasserted on every activation;
            # System Settings toggles can drift it between rebuilds.
            activationScripts.extraActivation.text = ''
              pmset -c sleep 0 womp 1
            '';

            defaults = {
              spaces.spans-displays = false;
              # universalaccess.reduceMotion = true;
              dock = {
                autohide = true;
                showhidden = true;
                mru-spaces = false;
                launchanim = false;
                persistent-apps = [
                  # Workspace 1: Term
                  "/Applications/Rex.app"
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
                InitialKeyRepeat = 10;
                KeyRepeat = 1;
                "com.apple.mouse.tapBehavior" = 1;
                "com.apple.swipescrolldirection" = false;
              };
              trackpad = {
                Clicking = true;
                TrackpadThreeFingerDrag = false;
              };
              CustomUserPreferences = {
                # Leader Key keeps its actions in config.json (stowed from
                # home/Library/Application Support/), but the activation hotkey
                # and popup theme live in UserDefaults only.
                "com.brnbw.Leader-Key" = {
                  # ctrl-space: carbon controlKey (0x1000) + kVK_Space (49).
                  KeyboardShortcuts_navigate = ''{"carbonModifiers":4096,"carbonKeyCode":49}'';
                  theme = "cheater";
                  autoOpenCheatsheet = "always";
                };
                # Maccy has no config file; everything is UserDefaults. Same
                # KeyboardShortcuts library as Leader Key, same carbon encoding.
                # History lives in its own SQLite store, nothing to stow.
                "org.p0deje.Maccy" = {
                  # cmd-shift-v: cmdKey (0x100) + shiftKey (0x200) + kVK_ANSI_V (9).
                  KeyboardShortcuts_popup = ''{"carbonModifiers":768,"carbonKeyCode":9}'';
                  pasteByDefault = true;
                  searchMode = "fuzzy";
                  historySize = 200;
                  popupPosition = "cursor";
                  showInStatusBar = false;
                  ignoredApps = [ "com.1password.1password" ];
                };
              };
            };
          };

          security.pam.services.sudo_local = {
            enable = true;
            touchIdAuth = true;
            reattach = true;
          };
          # Leave Remote Login (sshd) off by default on roaming macOS laptops;
          # `/etc/ssh/ssh_host_ed25519_key` for sops-nix persists via `sudo ssh-keygen -A`
          # without exposing sshd, and stationary Macs can opt in with `services.openssh.enable = true`.
          services.openssh.enable = lib.mkDefault false;

          programs.ssh.knownHosts = lib.my.mkKnownHosts lib.my.sshHostKeys;
          homebrew = {
            enable = true;
            greedyCasks = true;
            taps = [
              {
                name = "nikitabobko/tap";
                trusted = true;
              }
            ];
            brews = [
              "xcode-build-server"
              "xcbeautify"
              "xcp"
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
              "reaper"
              "brave-browser"
              "gimp"
              "xquartz"
              "obsidian"
              "aerospace"
              "leader-key"
              "maccy"
            ];
            onActivation = {
              autoUpdate = true;
              upgrade = true;
            };
          };

          # No Nix openssh here: macOS's ssh supports GSSAPI (Colima's ssh_config) and
          # UseKeychain, and overriding pkgs.openssh rebuilt everything that depends on it.
          environment.systemPackages = with pkgs; [ nh ];

          nixpkgs = {
            overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
            config = {
              allowUnfree = true;
              allowUnfreePredicate = _: true;
              allowBroken = true;
            };
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
        dotfilesSync = pkgs.callPackage ../../pkgs/dotfiles-sync { };
        # Absent when the flake was built from a dirty tree; the sync then skips.
        deployedRev = inputs.self.rev or "";
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
          # nix-direnv restores TMPDIR after loading the dev shell; the stdlib
          # use_flake leaks nix-shell.XXXXXX, overflowing macOS's 104-byte
          # unix socket limit (direnv/direnv#1057).
          direnv = {
            enable = true;
            nix-direnv.enable = true;
          };
          atuin = {
            enable = true;
            daemon.enable = true;
          };
          zoxide.enable = true;
          nix-index-database.comma.enable = true;
          # vscode.enable = true;
        };

        # Configure user nixpkgs
        nixpkgs = {
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
            allowBroken = true;
          };
        };

        home = {
          # User session variables
          sessionVariables = {
            NH_FLAKE = "${config.home.homeDirectory}/dotfiles/";
            SHELL = "${pkgs.zsh}/bin/zsh";
            LANG = "en_US.UTF-8";
            LC_ALL = "en_US.UTF-8";
            EDITOR = "nvim";
            VISUAL = "nvim";
            PAGER = "less";
            MANPAGER = "less -R --use-color -Dd+r -Du+b";
          };
          enableNixpkgsReleaseCheck = false;
          stateVersion = "26.05";
          homeDirectory = "/${homePrefix}/${config.home.username}";

          activation = {
            stowHome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              DOTFILES_DIR="${config.home.homeDirectory}/dotfiles"
              if [ ! -d "$DOTFILES_DIR" ]; then
                echo "Cloning dotfiles repo to $DOTFILES_DIR..."
                ${pkgs.git}/bin/git clone https://github.com/pperanich/dotfiles.git "$DOTFILES_DIR"
              fi
              run ${lib.getExe dotfilesSync} "$DOTFILES_DIR" "${deployedRev}" \
                || echo "dotfiles-sync failed; stowing the checkout as it is"
              pushd "$DOTFILES_DIR" >/dev/null
              ${pkgs.stow}/bin/stow home
              popd >/dev/null
              DOTFILES_REAL=$(${pkgs.coreutils}/bin/realpath -m -- "$DOTFILES_DIR")

              # Stow keeps a link after its source file leaves the repo, and a
              # dangling link breaks anything that enumerates the directory:
              # lazy.nvim failed to load five removed plugin files under
              # lua/plugins. Check only the directories the repo manages, one
              # level deep, and remove links that point into this repo at a path
              # that no longer exists. Every other link is left alone.
              managed=("$HOME")
              home_prefix="$DOTFILES_DIR/home"
              while IFS= read -r -d "" dir; do
                managed+=("$HOME''${dir#"$home_prefix"}")
              done < <(${pkgs.findutils}/bin/find "$DOTFILES_DIR/home" -type d -print0)
              while IFS= read -r -d "" link; do
                if [ -e "$link" ]; then
                  continue
                fi
                points_to=$(readlink -- "$link")
                case $points_to in
                  /*) resolved=$points_to ;;
                  *) resolved=$(dirname -- "$link")/$points_to ;;
                esac
                target=$(${pkgs.coreutils}/bin/realpath -m -- "$resolved")
                case $target in
                  "$DOTFILES_REAL"/*)
                    echo "stow: removing dangling link $link"
                    ${pkgs.coreutils}/bin/rm -f -- "$link"
                    ;;
                esac
              done < <(${pkgs.findutils}/bin/find "''${managed[@]}" -maxdepth 1 -type l -print0 2>/dev/null)
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
