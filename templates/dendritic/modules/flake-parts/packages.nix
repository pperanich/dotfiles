# Packages defined in /pkgs reach pkgs.* through the `additions` overlay;
# re-export them here so `nix build .#<name>` works.
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        inherit (pkgs) hello-dendritic;
      };
    };
}
