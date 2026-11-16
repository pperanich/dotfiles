# Rename this file, username, home-profiles/example, machine imports/options,
# and the passwords/example key in secrets.yaml.
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
        my.desktop.enable = lib.mkDefault config.my.${username}.desktop;

        sops.secrets."passwords/${username}".neededForUsers = true;

        users.users.${username} = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          shell = pkgs.zsh;
          packages = [ pkgs.home-manager ];
          hashedPasswordFile = config.sops.secrets."passwords/${username}".path;
          openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
        };

        programs.zsh.enable = true;

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
      ...
    }:
    {
      options.my.${username}.desktop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include desktop modules in this user's home profile.";
      };

      config = {
        my.desktop.enable = lib.mkDefault config.my.${username}.desktop;

        # Describes an account macOS already created. To create it with
        # nix-darwin, also give it a uid and add it to users.knownUsers.
        users.users.${username} = {
          home = "/Users/${username}";
          shell = pkgs.zsh;
          packages = [ pkgs.home-manager ];
          openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
        };

        system.primaryUser = username;

        # Note: trusted-users grants root-equivalent access to nix-daemon and is
        # omitted by default. Only enable it on hosts accepting unsigned remote-build
        # closures (via determinateNix.customSettings.trusted-users when Determinate
        # Nix is enabled, or nix.settings.trusted-users otherwise).

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
      };
    };
}
