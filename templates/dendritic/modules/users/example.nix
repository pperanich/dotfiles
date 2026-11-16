# Rename checklist when you make this your own:
#   1. this filename and the `example` attribute names below
#   2. home-profiles/example/
#   3. the `example` entry in each machine's imports
#   4. the `passwords/example` key in sops/secrets.yaml
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
      # these follow sops.defaultSopsFile, so a host defined in another flake
      # can repoint them at its own secrets file (see docs/private-repo.md).
      sops.secrets."passwords/${username}".neededForUsers = true;

      users.users.${username} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        shell = pkgs.bash;
        hashedPasswordFile = config.sops.secrets."passwords/${username}".path;
        openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
      };

      # Note: nix.settings.trusted-users is intentionally omitted by default
      # because Nix daemon trust is equivalent to passwordless root.

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
      # Describes an account macOS already created. To have nix-darwin create
      # it instead, give it a uid and add the name to users.knownUsers.
      users.users.${username} = {
        home = "/Users/${username}";
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = builtins.attrValues lib.my.sshKeys;
      };

      system.primaryUser = username;

      home-manager = {
        useUserPackages = true;
        extraSpecialArgs = { inherit (modules) homeManager; };
        users.${username}.imports = [ ../../home-profiles/example ];
      };
    };
}
