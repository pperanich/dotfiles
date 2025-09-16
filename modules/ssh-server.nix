# SSH server and client configuration module - dendritic pattern
_: {
  flake.modules.nixos.sshServer = {
    lib,
    config,
    pkgs,
    ...
  }: {
    # SSH server configuration for NixOS
    services.openssh = {
      enable = true;
      settings = {
        # Security settings - key-only authentication
        PasswordAuthentication = false;
        PubkeyAuthentication = true;
        AuthenticationMethods = "publickey";

        # Disable root login for security
        PermitRootLogin = "no";

        # Additional security settings
        PermitEmptyPasswords = false;
        ChallengeResponseAuthentication = false;
        UsePAM = true;

        # Protocol and encryption settings
        Protocol = 2;
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
        ];
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
          "aes256-ctr"
          "aes192-ctr"
          "aes128-ctr"
        ];
        Macs = [
          "hmac-sha2-256-etm@openssh.com"
          "hmac-sha2-512-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
      };

      # Additional SSH server options
      openFirewall = true;
      ports = [22];

      # Host keys configuration
      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
        {
          path = "/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
      ];
    };

    # SSH client configuration system-wide
    programs.ssh = {
      startAgent = true;
      extraConfig = ''
        Host *
          ServerAliveInterval 60
          ServerAliveCountMax 3
          TCPKeepAlive yes

        # Prefer newer algorithms
        KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
        MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
      '';
    };

    # Network configuration for SSH
    networking.firewall = {
      allowedTCPPorts = [22];
    };
  };

  flake.modules.darwin.sshServer = {
    lib,
    config,
    pkgs,
    ...
  }: {
    # SSH server configuration for macOS/Darwin
    # Note: macOS has built-in SSH server, but we can configure it

    # Enable SSH service on Darwin
    services.openssh = {
      enable = true;
    };

    # SSH client configuration for Darwin
    programs.ssh = {
      extraConfig = ''
        Host *
          ServerAliveInterval 60
          ServerAliveCountMax 3
          TCPKeepAlive yes
          AddKeysToAgent yes
          UseKeychain yes

        # Prefer newer algorithms
        KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
        MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
      '';
    };

    # macOS-specific SSH agent configuration
    launchd.user.agents.ssh-agent = {
      serviceConfig = {
        Label = "ssh-agent";
        ProgramArguments = ["${pkgs.openssh}/bin/ssh-agent" "-D" "-a" "%i/ssh-agent.socket"];
        Sockets.Listeners = {
          SockServiceName = "ssh-agent";
          SockPathName = "%i/ssh-agent.socket";
        };
      };
    };
  };

  flake.modules.homeModules.sshServer = {
    lib,
    config,
    pkgs,
    ...
  }: {
    # SSH client configuration and key management for Home Manager

    programs.ssh = {
      enable = true;

      # SSH client configuration
      extraConfig = ''
        Host *
          ServerAliveInterval 60
          ServerAliveCountMax 3
          TCPKeepAlive yes
          AddKeysToAgent yes

        # Security preferences
        HashKnownHosts yes
        StrictHostKeyChecking ask
        VerifyHostKeyDNS yes

        # Prefer newer algorithms
        KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
        MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
      '';

      # SSH agent configuration
      forwardAgent = false; # Disable by default for security
      addKeysToAgent = "yes";

      # Control master for connection sharing
      controlMaster = "auto";
      controlPath = "~/.ssh/control-%r@%h:%p";
      controlPersist = "10m";
    };

    # SSH service for agent management
    services.ssh-agent = {
      enable = true;
    };

    # Create SSH directory with proper permissions
    home.file.".ssh/.keep" = {
      text = "";
      onChange = ''
        chmod 700 ~/.ssh
      '';
    };

    # SSH key generation helper (commented out - user should generate manually)
    # home.activation.generateSSHKey = lib.hm.dag.entryAfter ["writeBoundary"] ''
    #   if [ ! -f ~/.ssh/id_ed25519 ]; then
    #     ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    #     chmod 600 ~/.ssh/id_ed25519
    #     chmod 644 ~/.ssh/id_ed25519.pub
    #   fi
    # '';
  };
}
