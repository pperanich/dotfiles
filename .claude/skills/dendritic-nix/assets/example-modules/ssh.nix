# SSH configuration - dendritic pattern example
_: {
  # NixOS SSH server configuration
  flake.modules.nixos.ssh-server =
    _:
    {
      services.openssh = {
        enable = true;
        ports = [ 22 ];
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          PubkeyAuthentication = true;
        };
      };

      networking.firewall.allowedTCPPorts = [ 22 ];
    };

  # home-manager SSH client configuration
  flake.modules.homeManager.ssh-client =
    { pkgs, ... }:
    {
      programs.ssh = {
        enable = true;

        matchBlocks = {
          "github.com" = {
            identitiesOnly = true;
            identityFile = "~/.ssh/id_ed25519";
          };
          "gitlab.com" = {
            identitiesOnly = true;
            identityFile = "~/.ssh/id_ed25519";
          };
        };

        extraConfig = ''
          AddKeysToAgent yes

          # Security settings
          Host *
            Protocol 2
            ForwardAgent no
            ForwardX11 no
            PasswordAuthentication no
        '';
      };

      home.packages = with pkgs; [
        openssh
        mosh # Mobile shell for better SSH over unreliable connections
      ];
    };

  # Darwin SSH client configuration (macOS)
  flake.modules.darwin.ssh-client = _: {
    programs.ssh.extraConfig = ''
      # macOS-specific SSH settings
      Host *
        UseKeychain yes
        AddKeysToAgent yes
    '';
  };
}
