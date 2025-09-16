# NixOS system hardening configuration
# Kernel parameters, SSH hardening, and network security settings
_: {
  flake.modules.nixos.securityTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Kernel security hardening
    boot.kernel.sysctl = {
      # Network security
      "net.ipv4.ip_forward" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.default.accept_source_route" = 0;

      # Enable TCP SYN cookies
      "net.ipv4.tcp_syncookies" = 1;

      # Ignore ICMP ping requests
      "net.ipv4.icmp_echo_ignore_all" = 0; # Set to 1 for high security

      # Enable IP spoofing protection
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;

      # Log suspicious packets
      "net.ipv4.conf.all.log_martians" = 1;
      "net.ipv4.conf.default.log_martians" = 1;
    };

    # Security-focused kernel modules
    boot.kernelModules = [
      "tcp_bbr" # Better congestion control
    ];

    # SSH hardening configuration
    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        Protocol = 2;
      };
    };

    # Additional security configurations
    security = {
      # Configure PAM for better authentication
      pam.loginLimits = [
        {
          domain = "*";
          type = "soft";
          item = "nofile";
          value = "65536";
        }
        {
          domain = "*";
          type = "hard";
          item = "nofile";
          value = "65536";
        }
      ];
    };
  };
}
