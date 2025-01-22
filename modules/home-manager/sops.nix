{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {
    defaultSopsFile = ../../sops/users/peranpl1.yaml;
    age = {
      keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
      generateKey = true;
    };
    
    secrets = {
      "ssh/id_ed25519" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519";
        mode = "0600";
        key = "ssh.keys.id_ed25519";
      };
      "gpg/private_key" = {
        path = "${config.home.homeDirectory}/.gnupg/private-keys-v1.d/key.pgp";
        mode = "0600";
        key = "gpg.private_key";
      };
      "git/signing_key" = {
        path = "${config.xdg.configHome}/git/signing_key";
        key = "git.signing_key";
      };
      "git/github_token" = {
        path = "${config.xdg.configHome}/git/github_token";
        key = "git.github_token";
      };
    };
  };
} 