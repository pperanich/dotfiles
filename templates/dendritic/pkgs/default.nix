# Custom packages. Reachable as pkgs.<name> everywhere (via the `additions`
# overlay) and as `nix build .#<name>` (via modules/flake-parts/packages.nix).
{ pkgs }:
{
  hello-dendritic = pkgs.callPackage ./hello-dendritic { };
}
