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
    defaultSopsFile = ../../sops/secrets.yaml;

    # Decrypt with an age key derived from this host's SSH host key, and put
    # that key's public half in sops/.sops.yaml:
    #   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
    # The upstream defaults to a clan-provisioned /var/lib/sops-nix/key.txt,
    # which nothing here creates.
    age = {
      keyFile = null;
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };

  # Keep SSH and its host keys available on subsequent boots.
  services.openssh.enable = true;

  # Apply the SOPS password hash on every activation, including existing users.
  # This also removes undeclared accounts and groups. Before adopting an
  # existing machine, follow README.md's account migration steps.
  users.mutableUsers = false;

  # The same home profile serves servers and desktops.
  my.example.desktop = false;

  networking.hostName = "example-nixos";
  nixpkgs.hostPlatform = "x86_64-linux";

  time.timeZone = "America/New_York";
  system.stateVersion = "26.05";
}
