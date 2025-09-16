_: {
  # NixOS system-level password and secrets management
  flake.modules.nixos.passwordManagement = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # System packages for password and secrets management
    environment.systemPackages = with pkgs; [
      # Core secret management tools
      age # Simple, modern and secure encryption tool
      sops # Secrets OPerationS - encrypt secrets with GPG, age, and cloud KMS
      gnupg # Complete and free implementation of the OpenPGP standard
      pinentry-curses # Minimal PIN entry dialog for GPG
      pinentry-gtk2 # GTK-based PIN entry dialog for GPG

      # Password managers - CLI
      pass # Standard Unix password manager
      gopass # Team password manager with Git backend
      bitwarden-cli # Command-line interface for Bitwarden

      # SSH and authentication
      openssh # Secure shell client and server
      keyutils # Linux key management utilities

      # Certificate management
      certbot # Let's Encrypt ACME client
      mkcert # Simple tool for making locally-trusted development certificates

      # Vault and enterprise tools
      vault # Secrets management for systems and applications

      # 2FA and OTP tools
      oath-toolkit # One-time password toolkit
      otpauth # Generate TOTP and HOTP codes

      # System keyring integration
      libsecret # GObject wrapper for Secret Service API
    ];

    # System services and configuration
    services = {
      # GPG agent configuration
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryPackage = pkgs.pinentry-curses;
      };

      # OpenSSH daemon with secure defaults
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
      };
    };

    # Security defaults and hardening
    security = {
      # Polkit for privilege escalation
      polkit.enable = true;

      # PAM configuration for better authentication
      pam.services = {
        login.enableGnomeKeyring = true;
        passwd.enableGnomeKeyring = true;
      };
    };

    # System environment variables
    environment.variables = {
      # GPG configuration
      GPG_TTY = "$(tty)";
      GNUPGHOME = "/etc/gnupg";

      # Pass configuration
      PASSWORD_STORE_DIR = "/var/lib/password-store";

      # Age configuration
      AGE_RECIPIENTS_FILE = "/etc/age/recipients";
    };

    # Create necessary directories
    system.activationScripts.passwordManagement = ''
      mkdir -p /etc/gnupg
      mkdir -p /etc/age
      mkdir -p /var/lib/password-store
      chmod 700 /etc/gnupg
      chmod 700 /etc/age
      chmod 700 /var/lib/password-store
    '';
  };

  # Home Manager user-level password and secrets management
  flake.modules.homeModules.passwordManagement = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.home) homeDirectory;
  in {
    home.packages = with pkgs;
      [
        # Password managers
        keepassxc # Cross-platform community-driven port of KeePass password manager
        bitwarden-cli # Command-line interface for Bitwarden
        pass # Standard Unix password manager
        gopass # Team password manager with Git backend
        pass-otp # Pass extension for managing OTP tokens

        # Secret management tools
        age # Simple, modern and secure encryption tool
        sops # Secrets OPerationS - encrypt secrets with GPG, age, and cloud KMS
        rage # Rust implementation of age

        # GPG and encryption
        gnupg # Complete and free implementation of the OpenPGP standard
        pinentry-curses # Minimal PIN entry dialog for GPG
        paperkey # Extract OpenPGP secret key for printing

        # SSH key management
        ssh-copy-id # Install SSH key on remote machine
        ssh-audit # SSH server & client auditing tool
        keychain # SSH key manager for shell sessions

        # 2FA and OTP tools
        oath-toolkit # One-time password toolkit
        otpauth # Generate TOTP and HOTP codes
        qrencode # QR code generator for 2FA setup
        zbar # QR code scanner for importing 2FA secrets

        # Certificate tools
        mkcert # Simple tool for making locally-trusted development certificates
        openssl # SSL/TLS toolkit

        # Vault tools
        vault # Secrets management for systems and applications
        consul-template # Template rendering using Vault secrets
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific packages
        libsecret # GObject wrapper for Secret Service API
        keyutils # Linux key management utilities
        gnome.seahorse # GNOME keyring manager

        # Linux 2FA GUI tools
        authenticator # Two-factor authentication code generator
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS will use system keychain integration
      ];

    # Programs configuration
    programs = {
      # GPG configuration
      gpg = {
        enable = true;
        settings = {
          # Keyserver configuration
          keyserver = "hkps://keys.openpgp.org";
          keyserver-options = "auto-key-retrieve";

          # Security settings
          personal-cipher-preferences = "AES256 AES192 AES";
          personal-digest-preferences = "SHA512 SHA384 SHA256";
          personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
          default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
          cert-digest-algo = "SHA512";
          s2k-digest-algo = "SHA512";
          s2k-cipher-algo = "AES256";
          charset = "utf-8";
          fixed-list-mode = true;
          no-comments = true;
          no-emit-version = true;
          no-greeting = true;
          keyid-format = "0xlong";
          list-options = "show-uid-validity";
          verify-options = "show-uid-validity";
          with-fingerprint = true;
          require-cross-certification = true;
          no-symkey-cache = true;
          use-agent = true;

          # Trust model
          trust-model = "pgp";
        };
      };

      # SSH configuration
      ssh = {
        enable = true;
        addKeysToAgent = "yes";
        controlMaster = "auto";
        controlPath = "${homeDirectory}/.ssh/master-%r@%n:%p";
        controlPersist = "10m";

        extraConfig = ''
          # Security settings
          HashKnownHosts yes
          VerifyHostKeyDNS yes
          VisualHostKey yes

          # Use stronger algorithms
          KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256
          HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,rsa-sha2-256,rsa-sha2-512
          Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
          MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
        '';
      };
    };

    # Services configuration
    services = {
      # GPG agent for user sessions
      gpg-agent = {
        enable = true;
        enableSshSupport = true;
        pinentryPackage =
          if pkgs.stdenv.hostPlatform.isDarwin
          then pkgs.pinentry_mac
          else pkgs.pinentry-gtk2;
        defaultCacheTtl = 1800; # 30 minutes
        maxCacheTtl = 7200; # 2 hours

        extraConfig = ''
          allow-emacs-pinentry
          allow-loopback-pinentry
        '';
      };

      # SSH agent (fallback if not using GPG agent)
      ssh-agent.enable = false; # Disabled in favor of GPG agent
    };

    # Environment variables and session setup
    home = {
      sessionVariables = {
        # GPG configuration
        GPG_TTY = "$(tty)";

        # Pass configuration
        PASSWORD_STORE_DIR = "${homeDirectory}/.password-store";
        PASSWORD_STORE_GENERATED_LENGTH = "32";
        PASSWORD_STORE_CHARACTER_SET = "[:alnum:][:punct:]";
        PASSWORD_STORE_ENABLE_EXTENSIONS = "true";

        # Age configuration
        AGE_RECIPIENTS_FILE = "${homeDirectory}/.config/age/recipients";

        # SOPS configuration
        SOPS_AGE_RECIPIENTS = "${homeDirectory}/.config/sops/age/keys.txt";

        # Vault configuration
        VAULT_ADDR = "https://vault.example.com"; # Override in host-specific config
      };

      sessionPath = [
        "${homeDirectory}/.local/bin"
      ];
    };

    # Shell aliases and functions
    programs.zsh.shellAliases = {
      # Password management shortcuts
      "pf" = "pass find";
      "pg" = "pass generate -c";
      "pi" = "pass insert -m";
      "ps" = "pass show -c";
      "pe" = "pass edit";
      "pr" = "pass rm";

      # GPG shortcuts
      "gpg-list-keys" = "gpg --list-keys --keyid-format LONG";
      "gpg-list-secret-keys" = "gpg --list-secret-keys --keyid-format LONG";
      "gpg-export-key" = "gpg --armor --export";
      "gpg-export-secret-key" = "gpg --armor --export-secret-key";

      # SSH key management
      "ssh-keygen-ed25519" = "ssh-keygen -t ed25519 -C";
      "ssh-add-all" = "ssh-add ~/.ssh/id_*";
      "ssh-list-keys" = "ssh-add -l";

      # Age encryption shortcuts
      "age-keygen" = "age-keygen -o ${homeDirectory}/.config/age/key.txt";
      "age-encrypt" = "age -r";
      "age-decrypt" = "age --decrypt -i ${homeDirectory}/.config/age/key.txt";

      # SOPS shortcuts
      "sops-encrypt" = "sops --encrypt --in-place";
      "sops-decrypt" = "sops --decrypt";
      "sops-edit" = "sops";

      # Vault shortcuts
      "vault-login" = "vault auth -method=userpass username=$USER";
      "vault-status" = "vault status";

      # 2FA shortcuts
      "otp-generate" = "oathtool --totp -b";
      "qr-scan" = "zbarcam --oneshot --raw";
    };

    # XDG configuration directories
    xdg.configFile = {
      # Age recipients file template
      "age/recipients".text = ''
        # Add your age public keys here
        # One key per line
      '';

      # SOPS configuration
      "sops/age/keys.txt".text = ''
        # SOPS age keys
        # Generated keys will be stored here
      '';
    };

    # Create necessary directories
    home.activation.passwordManagement = config.lib.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p ${homeDirectory}/.config/age
      $DRY_RUN_CMD mkdir -p ${homeDirectory}/.config/sops/age
      $DRY_RUN_CMD mkdir -p ${homeDirectory}/.gnupg
      $DRY_RUN_CMD mkdir -p ${homeDirectory}/.password-store

      # Set proper permissions
      $DRY_RUN_CMD chmod 700 ${homeDirectory}/.gnupg
      $DRY_RUN_CMD chmod 700 ${homeDirectory}/.config/age
      $DRY_RUN_CMD chmod 700 ${homeDirectory}/.config/sops
      $DRY_RUN_CMD chmod 700 ${homeDirectory}/.password-store
    '';
  };

  # Darwin system-level password and secrets management
  flake.modules.darwin.passwordManagement = {pkgs, ...}: {
    # macOS system packages
    environment.systemPackages = with pkgs; [
      # Core tools that integrate well with macOS
      gnupg
      pinentry_mac # macOS native pinentry
      openssh
      age
      sops
      vault
      mkcert

      # Password managers with good macOS integration
      bitwarden-cli
    ];

    # System configuration for macOS
    system = {
      # Keyboard shortcuts and accessibility
      keyboard = {
        enableKeyMapping = true;
      };
    };

    # Homebrew packages for better system integration
    homebrew = {
      # GUI applications that integrate better via Homebrew
      casks = [
        "keepassxc" # KeePass password manager
        "bitwarden" # Bitwarden password manager
        "gpg-suite" # GPG suite with Keychain integration
      ];

      # Formulae for system integration
      brews = [
        "pinentry-mac" # Native macOS pinentry
      ];
    };

    # LaunchAgents for background services
    launchd.user.agents = {
      gpg-agent = {
        path = [pkgs.gnupg];
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.gnupg}/bin/gpg-connect-agent"
            "/bye"
          ];
          RunAtLoad = true;
          KeepAlive = false;
        };
      };
    };

    # System security settings
    system.defaults = {
      # Security preferences
      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

      # Enable TouchID for sudo (requires manual setup)
      # Users should run: sudo vim /etc/pam.d/sudo
      # And add: auth sufficient pam_tid.so
    };

    # Environment variables for system-wide access
    environment.variables = {
      # GPG configuration
      GPG_TTY = "$(tty)";

      # SSH agent socket for system services
      SSH_AUTH_SOCK = "/run/user/$(id -u)/ssh-agent.socket";
    };
  };
}
