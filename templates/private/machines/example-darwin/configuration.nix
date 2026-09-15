{ modules, ... }:
{
  imports = with modules.darwin; [
    base
    sops
    example
  ];

  # Enable Remote Login and run `sudo ssh-keygen -A` before the first switch.
  # Encrypt to this persistent host key. The user's key is deployed FROM sops,
  # so using it here would prevent decryption after reboot clears /run/secrets.
  sops = {
    defaultSopsFile = ../../sops/secrets.yaml;
    age = {
      keyFile = null;
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };

  networking.hostName = "example-darwin";
  services.openssh.enable = true;
  my.example.desktop = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 6;
}
