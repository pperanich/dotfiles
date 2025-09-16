# SOPS secrets management - Dendritic module
# Provides unified SOPS configuration for NixOS, Darwin, and Home Manager
_: let
  sopsFolder = "sops/";
in {
  flake.modules = {
    # NixOS system-level SOPS configuration
    nixos.sopsSecrets = {
      inputs,
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [inputs.sops-nix.nixosModules.sops];

      # System packages
      environment.systemPackages = [pkgs.sops];

      # SOPS configuration
      sops = {
        # Test secret (can be removed in production)
        secrets."test/a" = {};

        # User password secrets (needed for user creation)
        secrets.pperanich-password = {
          neededForUsers = true;
        };
        secrets.peranpl1-password = {
          neededForUsers = true;
        };

        # Default secrets file location
        defaultSopsFile = lib.path.append config.my.configPath sopsFolder + "/secrets.yaml";
        validateSopsFiles = false;

        # Age key configuration
        age = {
          # Automatically import host SSH keys as age keys
          sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
        };

        # Secrets will be output to /run/secrets
        # e.g. /run/secrets/msmtp-password
        # User-specific secrets are handled in Home Manager configuration
      };
    };

    # Darwin (macOS) SOPS configuration
    darwin.sopsSecrets = {
      inputs,
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [inputs.sops-nix.darwinModules.sops];

      # System packages
      environment.systemPackages = [pkgs.sops];

      # SOPS configuration for macOS
      sops = {
        # Test secret (can be removed in production)
        secrets."test/a" = {};

        # Default secrets file location
        defaultSopsFile = lib.path.append config.my.configPath sopsFolder + "/secrets.yaml";
        validateSopsFiles = false;

        # Age key configuration for macOS
        age = {
          # Use system SSH keys for age key derivation
          sshKeyPaths = [
            "/etc/ssh/ssh_host_ed25519_key"
            "/etc/ssh/ssh_host_rsa_key"
          ];
        };
      };
    };

    # Home Manager user-level SOPS configuration
    homeModules.sopsSecrets = {
      inputs,
      config,
      lib,
      pkgs,
      ...
    }: let
      inherit (config.home) username homeDirectory;
    in {
      imports = [inputs.sops-nix.homeManagerModules.sops];

      # User packages
      home.packages = [pkgs.sops];

      # SOPS configuration for user
      sops = {
        # Package configuration with GODEBUG fix for x509 issues
        package = pkgs.sops-install-secrets.overrideAttrs (old: {
          env.GODEBUG = "x509negativeserial=1";
        });

        # Age key configuration
        age = {
          # User-specific age key file location
          keyFile = "${homeDirectory}/.config/sops/age/keys.txt";
          # User SSH keys for age key derivation
          sshKeyPaths = [
            "${homeDirectory}/.ssh/id_ed25519"
          ];
        };

        # Default secrets file location
        defaultSopsFile = lib.path.append config.my.configPath sopsFolder + "/secrets.yaml";
        validateSopsFiles = true;

        # User-level secrets
        secrets = {
          # API keys for various services
          "api_keys/opal_api_key" = {};
          "api_keys/openai_api_key" = {};
          "api_keys/assemblyai_api_key" = {};
          "api_keys/hugging_face_hub_token" = {};
          "api_keys/anthropic_api_key" = {};
          "api_keys/mistral_api_key" = {};
          "api_keys/openrouter_api_key" = {};
          "api_keys/gemini_api_key" = {};

          # Private SSH key
          "private_keys/${username}" = {
            path = "${homeDirectory}/.ssh/id_ed25519";
            mode = "0400";
          };
        };
      };

      # Shell integration for API keys (if zsh is enabled)
      programs.zsh = lib.mkIf (config.programs.zsh.enable or false) {
        initExtra = ''
          # Export API keys from SOPS secrets
          export OPAL_API_KEY=$(cat ${config.sops.secrets."api_keys/opal_api_key".path} 2>/dev/null || true)
          export OPENAI_API_KEY=$(cat ${config.sops.secrets."api_keys/openai_api_key".path} 2>/dev/null || true)
          export ASSEMBLYAI_API_KEY=$(cat ${config.sops.secrets."api_keys/assemblyai_api_key".path} 2>/dev/null || true)
          export HUGGING_FACE_HUB_TOKEN=$(cat ${config.sops.secrets."api_keys/hugging_face_hub_token".path} 2>/dev/null || true)
          export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."api_keys/anthropic_api_key".path} 2>/dev/null || true)
          export MISTRAL_API_KEY=$(cat ${config.sops.secrets."api_keys/mistral_api_key".path} 2>/dev/null || true)
          export OPENROUTER_API_KEY=$(cat ${config.sops.secrets."api_keys/openrouter_api_key".path} 2>/dev/null || true)
          export GEMINI_API_KEY=$(cat ${config.sops.secrets."api_keys/gemini_api_key".path} 2>/dev/null || true)
        '';
      };

      # Bash integration for API keys (if bash is enabled)
      programs.bash = lib.mkIf (config.programs.bash.enable or false) {
        initExtra = ''
          # Export API keys from SOPS secrets
          export OPAL_API_KEY=$(cat ${config.sops.secrets."api_keys/opal_api_key".path} 2>/dev/null || true)
          export OPENAI_API_KEY=$(cat ${config.sops.secrets."api_keys/openai_api_key".path} 2>/dev/null || true)
          export ASSEMBLYAI_API_KEY=$(cat ${config.sops.secrets."api_keys/assemblyai_api_key".path} 2>/dev/null || true)
          export HUGGING_FACE_HUB_TOKEN=$(cat ${config.sops.secrets."api_keys/hugging_face_hub_token".path} 2>/dev/null || true)
          export ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."api_keys/anthropic_api_key".path} 2>/dev/null || true)
          export MISTRAL_API_KEY=$(cat ${config.sops.secrets."api_keys/mistral_api_key".path} 2>/dev/null || true)
          export OPENROUTER_API_KEY=$(cat ${config.sops.secrets."api_keys/openrouter_api_key".path} 2>/dev/null || true)
          export GEMINI_API_KEY=$(cat ${config.sops.secrets."api_keys/gemini_api_key".path} 2>/dev/null || true)
        '';
      };
    };
  };
}
