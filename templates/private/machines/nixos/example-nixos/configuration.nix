# A machine is a list of modules plus the handful of settings only this host
# cares about. `modules` is a specialArg holding the upstream's modules with
# this repo's merged over them (see modules/flake-parts/hosts.nix).
{ modules, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ]
  ++ (with modules.nixos; [
    base
    sops
    example
  ]);

  # Both lines are load-bearing; see docs/upstream-contract.md.
  #
  # defaultSopsFile resolves where the upstream's sops module is written, so
  # without this the host looks for secrets in the upstream's store path, which
  # its key is not a recipient of. The upstream sets it at priority 900, so a
  # plain assignment wins.
  sops = {
    defaultSopsFile = ../../../sops/secrets.yaml;

    # Decrypt with an age key derived from this host's SSH host key, and put
    # that key's public half in sops/.sops.yaml:
    #   ssh-keyscan <host> | ssh-to-age
    # The upstream defaults to a clan-provisioned /var/lib/sops-nix/key.txt,
    # which nothing here creates.
    age = {
      keyFile = null;
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };

  # Needed to decrypt at boot: without it the host key does not exist yet.
  services.openssh.enable = true;

  networking.hostName = "example-nixos";
  nixpkgs.hostPlatform = "x86_64-linux";

  time.timeZone = "America/New_York";
  system.stateVersion = "26.05";
}
