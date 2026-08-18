# Rename checklist when you make this your own:
#   1. this filename and the `example` attribute names below
#   2. home-profiles/example/
#   3. the `example` entry in each machine's imports
#   4. the `passwords/example` and `private_keys/example` keys in sops/secrets.yaml
#
# This is a local copy rather than an import of the upstream's user module,
# because that module hardcodes the upstream's own sops file and expects clan
# to create the account. Everything the *home* side does still comes from
# upstream: see home-profiles/example/.
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
      # Login password, decrypted before users are created. No sopsFile here —
      # these follow sops.defaultSopsFile, which each machine points at this
      # repo's own secrets.yaml.
      sops.secrets."passwords/${username}".neededForUsers = true;

      # The user's SSH private key, deployed by the *system* so home-manager's
      # sops has a key to decrypt with when it runs later in the activation.
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
        # `pkgs` is passed deliberately: home-manager otherwise builds its own
        # nixpkgs without the upstream's overlays, and the upstream's own home
        # modules expect packages those overlays add (sops-install-secrets).
        extraSpecialArgs = {
          inherit pkgs;
          inherit (modules) homeManager;
        };
        users.${username}.imports = [ ../../home-profiles/example ];
      };
    };

  flake.modules.darwin.${username} =
    {
      lib,
      pkgs,
      modules,
      ...
    }:
    {
      sops.secrets."private_keys/${username}" = {
        owner = username;
        group = "staff";
        mode = "0400";
        path = "/Users/${username}/.ssh/id_ed25519";
      };

      # Describes an account macOS already created. To have nix-darwin create
      # it instead, give it a uid and add the name to users.knownUsers.
      users.users.${username} = {
        home = "/Users/${username}";
        shell = pkgs.zsh;
        packages = [ pkgs.home-manager ];
        openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
      };

      system.primaryUser = username;
      nix.settings.trusted-users = [ username ];

      # zim's completion module owns compinit; skip nix-darwin's global one
      programs.zsh.enableGlobalCompInit = false;

      home-manager = {
        useUserPackages = true;
        # `pkgs` is passed deliberately: home-manager otherwise builds its own
        # nixpkgs without the upstream's overlays, and the upstream's own home
        # modules expect packages those overlays add (sops-install-secrets).
        extraSpecialArgs = {
          inherit pkgs;
          inherit (modules) homeManager;
        };
        users.${username}.imports = [ ../../home-profiles/example ];
      };
    };
}
