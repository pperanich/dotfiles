# Private files join the upstream's Stow package in the same home directory.
# Both repos can share directories, but must not claim the same file.
_:
let
  repo = import ../../lib/repo.nix;
in
{
  flake.modules.homeManager.stowPrivate =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.activation.stowPrivateHome = lib.hm.dag.entryAfter [ "stowHome" ] ''
        privateDir=${lib.escapeShellArg "${config.home.homeDirectory}/${repo.dirName}"}
        if [ -d "$privateDir/home" ]; then
          # Link individual files so application-written state stays outside
          # the checkout. Stow fails on conflicts instead of replacing files.
          run ${pkgs.stow}/bin/stow --no-folding \
            --dir "$privateDir" --target ${lib.escapeShellArg config.home.homeDirectory} home
        else
          echo "stowPrivate: $privateDir/home not found. Clone the private repo there; nh also uses this checkout." >&2
        fi
      '';
    };
}
