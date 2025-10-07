_: {
  # # NixOS system-level SSH server configuration
  # flake.modules.nixos.ssh-server =
  #   {
  #     config,
  #     lib,
  #     pkgs,
  #     ...
  #   }:
  #   let
  #     cfg = config.features.ssh-server;
  #   in
  #   {
  #     options.features.ssh-server = {
  #       port = lib.mkOption {
  #         type = lib.types.port;
  #         default = 22;
  #         description = "SSH server port";
  #       };
  #       allowedUsers = lib.mkOption {
  #         type = lib.types.listOf lib.types.str;
  #         default = [ ];
  #         example = [
  #           "user1"
  #           "user2"
  #         ];
  #         description = "Users allowed to connect via SSH";
  #       };
  #       allowedGroups = lib.mkOption {
  #         type = lib.types.listOf lib.types.str;
  #         default = [ "wheel" ];
  #         description = "Groups allowed to connect via SSH";
  #       };
  #       maxAuthTries = lib.mkOption {
  #         type = lib.types.int;
  #         default = 3;
  #         description = "Maximum authentication attempts";
  #       };
  #       clientAliveInterval = lib.mkOption {
  #         type = lib.types.int;
  #         default = 300;
  #         description = "Client alive interval in seconds";
  #       };
  #     };
  #
  #     config = {
  #       # OpenSSH service
  #       services.openssh = {
  #         enable = true;
  #         ports = [ cfg.port ];
  #
  #         settings = {
  #           # Security settings
  #           PasswordAuthentication = false;
  #           PermitRootLogin = "no";
  #           PubkeyAuthentication = true;
  #           AuthenticationMethods = "publickey";
  #           KbdInteractiveAuthentication = false;
  #           ChallengeResponseAuthentication = false;
  #
  #           # Protocol settings
  #           Protocol = 2;
  #           MaxAuthTries = cfg.maxAuthTries;
  #           LoginGraceTime = 30;
  #
  #           # Connection settings
  #           ClientAliveInterval = cfg.clientAliveInterval;
  #           ClientAliveCountMax = 2;
  #           TCPKeepAlive = false;
  #
  #           # Feature restrictions
  #           AllowTcpForwarding = "yes";
  #           AllowAgentForwarding = "yes";
  #           GatewayPorts = "no";
  #           X11Forwarding = false;
  #           PrintMotd = false;
  #
  #           # User restrictions
  #           AllowUsers = lib.mkIf (cfg.allowedUsers != [ ]) cfg.allowedUsers;
  #           AllowGroups = cfg.allowedGroups;
  #
  #           # Logging
  #           LogLevel = "VERBOSE";
  #
  #           # Modern crypto
  #           KexAlgorithms = [
  #             "curve25519-sha256"
  #             "curve25519-sha256@libssh.org"
  #             "ecdh-sha2-nistp521"
  #             "ecdh-sha2-nistp384"
  #             "ecdh-sha2-nistp256"
  #             "diffie-hellman-group16-sha512"
  #             "diffie-hellman-group18-sha512"
  #           ];
  #
  #           Ciphers = [
  #             "chacha20-poly1305@openssh.com"
  #             "aes256-gcm@openssh.com"
  #             "aes128-gcm@openssh.com"
  #             "aes256-ctr"
  #             "aes192-ctr"
  #             "aes128-ctr"
  #           ];
  #
  #           Macs = [
  #             "hmac-sha2-256-etm@openssh.com"
  #             "hmac-sha2-512-etm@openssh.com"
  #             "umac-128-etm@openssh.com"
  #             "hmac-sha2-256"
  #             "hmac-sha2-512"
  #             "umac-128@openssh.com"
  #           ];
  #         };
  #
  #         # Host keys
  #         hostKeys = [
  #           {
  #             path = "/etc/ssh/ssh_host_ed25519_key";
  #             type = "ed25519";
  #           }
  #           {
  #             path = "/etc/ssh/ssh_host_rsa_key";
  #             type = "rsa";
  #             bits = 4096;
  #           }
  #         ];
  #       };
  #
  #       # Firewall
  #       networking.firewall.allowedTCPPorts = [ cfg.port ];
  #
  #       # Fail2ban for SSH protection
  #       services.fail2ban = {
  #         enable = true;
  #         maxretry = 3;
  #         bantime = "1h";
  #         bantime-increment.enable = true;
  #         jails = {
  #           sshd = {
  #             settings = {
  #               enabled = true;
  #               port = toString cfg.port;
  #               filter = "sshd";
  #               logpath = "/var/log/auth.log";
  #               maxretry = cfg.maxAuthTries;
  #               bantime = "1h";
  #             };
  #           };
  #         };
  #       };
  #
  #       # Additional security packages
  #       environment.systemPackages = with pkgs; [
  #         openssh
  #         fail2ban
  #       ];
  #
  #       # SSH client configuration for system
  #       programs.ssh = {
  #         startAgent = true;
  #         extraConfig = ''
  #           # Client security settings
  #           Host *
  #             Protocol 2
  #             ForwardAgent no
  #             ForwardX11 no
  #             PasswordAuthentication no
  #             ChallengeResponseAuthentication no
  #             StrictHostKeyChecking ask
  #             VerifyHostKeyDNS yes
  #             NoHostAuthenticationForLocalhost yes
  #
  #             # Modern crypto for client
  #             KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256
  #             Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
  #             MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
  #         '';
  #       };
  #     };
  #   };
  #
  # # Darwin SSH configuration
  # flake.modules.darwin.ssh-server = _: {
  #   # SSH client configuration for macOS
  #   programs.ssh = {
  #     extraConfig = ''
  #       # Client security settings
  #       Host *
  #         Protocol 2
  #         ForwardAgent no
  #         ForwardX11 no
  #         PasswordAuthentication no
  #         ChallengeResponseAuthentication no
  #         StrictHostKeyChecking ask
  #         VerifyHostKeyDNS yes
  #         NoHostAuthenticationForLocalhost yes
  #
  #         # Modern crypto for client
  #         KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256
  #         Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
  #         MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
  #     '';
  #   };
  # };
  #
  # # Home Manager SSH tools
  # flake.modules.homeManager.ssh-server =
  #   { pkgs, ... }:
  #   {
  #     home.packages = with pkgs; [
  #       openssh
  #       mosh # Mobile shell for better SSH over unreliable connections
  #     ];
  #
  #     programs.ssh = {
  #       enable = true;
  #       extraConfig = ''
  #         # User SSH client security
  #         Host *
  #           Protocol 2
  #           ForwardAgent no
  #           ForwardX11 no
  #           PasswordAuthentication no
  #           StrictHostKeyChecking ask
  #           VerifyHostKeyDNS yes
  #
  #           # Modern crypto
  #           KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256
  #           Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
  #           MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
  #       '';
  #     };
  #   };
}
