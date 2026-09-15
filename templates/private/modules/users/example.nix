# Rename this file, username, home-profiles/example, machine imports/options,
# and the passwords/example and private_keys/example keys in secrets.yaml.
_:
let
  username = "example";
in
{
  flake.modules.nixos.${username} =
    {
      config,
      lib,
      pkgs,
      modules,
      ...
    }:
    {
      options.my.${username}.desktop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include desktop modules in this user's home profile.";
      };

      config = {
        sops.secrets."passwords/${username}".neededForUsers = true;

        # The host key decrypts this before Home Manager needs the user's key.
        sops.secrets."private_keys/${username}" = {
          owner = username;
          group = "users";
          mode = "0400";
          path = "/home/${username}/.ssh/id_ed25519";
        };

        users.users.${username} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "keys"
          ];
          shell = pkgs.zsh;
          packages = [ pkgs.home-manager ];
          hashedPasswordFile = config.sops.secrets."passwords/${username}".path;
          openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
        };

        programs.zsh.enable = true;
        nix.settings.trusted-users = [ username ];

        home-manager = {
          useUserPackages = true;
          extraSpecialArgs = {
            # Keep the system's overlays in Home Manager.
            inherit pkgs;
            inherit (modules) homeManager;
            # imports may read specialArgs, but not Home Manager's own config.
            desktop = config.my.${username}.desktop;
          };
          users.${username}.imports = [ ../../home-profiles/example ];
        };
      };
    };

  flake.modules.darwin.${username} =
    {
      config,
      lib,
      pkgs,
      modules,
      options,
      ...
    }:
    let
      usingDeterminate = config.determinateNix.enable or false;
    in
    {
      options.my.${username}.desktop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include desktop modules in this user's home profile.";
      };

      config = {
        sops.secrets."private_keys/${username}" = {
          owner = username;
          group = "staff";
          mode = "0400";
          path = "/Users/${username}/.ssh/id_ed25519";
        };

        # Describes an account macOS already created. To create it with
        # nix-darwin, also give it a uid and add it to users.knownUsers.
        users.users.${username} = {
          home = "/Users/${username}";
          shell = pkgs.zsh;
          packages = [ pkgs.home-manager ];
          openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
        };

        system.primaryUser = username;
        nix.settings.trusted-users = lib.mkIf (!usingDeterminate) [ username ];

        # zim owns compinit.
        programs.zsh.enableGlobalCompInit = false;

        home-manager = {
          useUserPackages = true;
          extraSpecialArgs = {
            inherit pkgs;
            inherit (modules) homeManager;
            desktop = config.my.${username}.desktop;
          };
          users.${username}.imports = [ ../../home-profiles/example ];
        };
      }
      // lib.optionalAttrs (options ? determinateNix.customSettings) {
        # Determinate disables nix-darwin's nix.settings. Remote builds need
        # trusted-users in the active daemon's config to accept unsigned paths.
        determinateNix.customSettings.trusted-users = lib.mkIf usingDeterminate [ username ];
      };
    };
}
