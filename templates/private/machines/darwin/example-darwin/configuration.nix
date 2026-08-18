{ modules, ... }:
{
  imports = with modules.darwin; [
    base
    sops
    example
  ];

  # See the nixos machine and docs/upstream-contract.md. macOS has no
  # /etc/ssh/ssh_host_ed25519_key until Remote Login is enabled, so a darwin
  # host usually decrypts with your own key instead.
  sops = {
    defaultSopsFile = ../../../sops/secrets.yaml;
    age = {
      keyFile = null;
      sshKeyPaths = [ "/Users/example/.ssh/id_ed25519" ];
    };
  };

  networking.hostName = "example-darwin";
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 6;
}
