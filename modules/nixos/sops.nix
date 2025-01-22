{ config, lib, pkgs, inputs, ... }:

{
  imports = [ 
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../../sops/secrets.yaml;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    
    secrets = {
      user-password = {
        key = "users.peranpl1.hashedPassword";
        neededForUsers = true;
      };
      root-password = {
        key = "users.root.hashedPassword";
        neededForUsers = true;
      };
      "wireless/home" = {
        key = "wireless.networks.home.psk";
      };
      "postgres/password" = {
        key = "services.postgres.password";
        owner = "postgres";
      };
    };
  };
} 