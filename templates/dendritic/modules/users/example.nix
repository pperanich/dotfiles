# Rename checklist when you make this your own:
#   1. this filename and the `example` attribute names below
#   2. home-profiles/example/
#   3. the `example` entry in each machine's imports
#   4. the `passwords/example` and `private_keys/example` keys in sops/secrets.yaml
_:
let
  username = "example";
  sopsFolder = ../../sops;
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
      # Login password, decrypted before users are created
      sops.secrets."passwords/${username}" = {
        sopsFile = "${sopsFolder}/secrets.yaml";
        neededForUsers = true;
      };

      # The user's SSH private key, deployed by the *system* so home-manager's
      # sops has a key to decrypt with on the next activation step
      sops.secrets."private_keys/${username}" = {
        sopsFile = "${sopsFolder}/secrets.yaml";
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
        shell = pkgs.bash;
        hashedPasswordFile = config.sops.secrets."passwords/${username}".path;
        openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
      };

      nix.settings.trusted-users = [ username ];

      # The same home profile the standalone homeConfigurations use
      home-manager = {
        useUserPackages = true;
        extraSpecialArgs = { inherit (modules) homeManager; };
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
        sopsFile = "${sopsFolder}/secrets.yaml";
        owner = username;
        group = "staff";
        mode = "0400";
        path = "/Users/${username}/.ssh/id_ed25519";
      };

      # Describes an account macOS already created. To have nix-darwin create
      # it instead, give it a uid and add the name to users.knownUsers.
      users.users.${username} = {
        home = "/Users/${username}";
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
      };

      system.primaryUser = username;
      nix.settings.trusted-users = [ username ];

      home-manager = {
        useUserPackages = true;
        extraSpecialArgs = { inherit (modules) homeManager; };
        users.${username}.imports = [ ../../home-profiles/example ];
      };
    };
}
