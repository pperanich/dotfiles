# Optional features that can be enabled per-host
{
  couchdb = import ./couchdb.nix;
  tailscale = import ./tailscale.nix;
  wsl = import ./wsl.nix;
}
