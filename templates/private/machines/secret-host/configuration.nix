# Written exactly like a machine in the upstream repo: a list of its modules
# plus the settings only this host cares about. `modules` is a specialArg
# holding the upstream's flake.modules (see modules/flake-parts/clan.nix).
{ modules, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ]
  ++ (with modules.nixos; [
    base
    sops
  ]);

  # Both of these are load-bearing; see docs/upstream-contract.md.
  #
  # defaultSopsFile resolves where the upstream's sops module is written, so
  # without this line the host looks for secrets in the upstream's store path,
  # which its age key is not a recipient of. The upstream sets these with
  # mkDefault, so a plain assignment wins.
  sops.defaultSopsFile = ../../sops/secrets.yaml;

  # Provisioned by `clan vars upload`, not by the host's SSH key. This is a
  # large part of why a private machine wants clan rather than a bare
  # nixosSystem call.
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  clan.core.networking.targetHost = "root@secret-host";

  networking.hostName = "secret-host";
  nixpkgs.hostPlatform = "x86_64-linux";
}
