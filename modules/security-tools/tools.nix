# CLI security tools for all platforms (NixOS, Darwin, Home Manager)
# Network analysis, vulnerability assessment, code analysis, and forensics tools
_: {
  # NixOS system configuration - CLI tools only
  flake.modules.nixos.securityTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # System-level security packages
    environment.systemPackages = with pkgs;
      [
        # Network analysis and monitoring
        nmap # Network mapper for discovery and security auditing
        tcpdump # Command-line packet analyzer
        wireshark-cli # Network protocol analyzer (command line)
        netcat-gnu # Networking utility for reading/writing network connections
        masscan # Fast TCP port scanner
        hping # Network tool able to send custom TCP/IP packets
        socat # Multipurpose relay for bidirectional data transfer

        # SSL/TLS analysis
        testssl # Testing TLS/SSL encryption anywhere on any port
        sslscan # Tests SSL/TLS enabled services to discover supported cipher suites
        sslyze # Fast and powerful SSL/TLS scanning library

        # Vulnerability scanning
        nuclei # Fast and customizable vulnerability scanner
        nikto # Web server scanner
        dirb # Web Content Scanner
        gobuster # Directory/File, DNS and VHost busting tool written in Go
        wpscan # WordPress security scanner
        sqlmap # Automatic SQL injection and database takeover tool

        # System hardening and monitoring
        lynis # Security auditing tool for Unix-based systems
        chkrootkit # Tool to check for RootKits
        rkhunter # Rootkit Hunter
        aide # File and directory integrity checker
        tripwire # File integrity monitoring
        samhain # File integrity and host-based intrusion detection

        # Password security (for authorized testing)
        hashcat # Advanced password recovery utility
        john # John the Ripper password cracker
        hydra # Very fast network logon cracker

        # Code analysis and SAST
        semgrep # Static analysis tool for finding bugs
        bandit # Security linter for Python code
        safety # Checks Python dependencies for known vulnerabilities

        # Container security
        trivy # Vulnerability scanner for containers and other artifacts
        grype # Vulnerability scanner for container images and filesystems

        # Forensics tools
        sleuthkit # Collection of command line file system and media management forensic analysis tools
        volatility3 # Advanced memory forensics framework

        # Network utilities for security testing
        dnsutils # DNS lookup utilities
        whois # Client for the whois directory service
        curl # Command line tool for transferring data with URL syntax

        # System analysis
        strace # System call tracer
        ltrace # Library call tracer
        gdb # GNU debugger
        binwalk # Tool for analyzing and extracting firmware images
        foremost # Console program to recover files
      ]
      ++ lib.optionals (lib.versionAtLeast (lib.versions.majorMinor lib.version) "23.05") [
        # Newer packages that may not be available in older NixOS versions
        osv-scanner # Vulnerability scanner which uses the OSV database
      ];
  };

  # Home Manager user configuration
  flake.modules.homeModules.securityTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # Network analysis tools
        nmap # Network discovery and security auditing
        netcat-gnu # Network utility for reading/writing connections
        tcpdump # Network packet analyzer
        wireshark # Network protocol analyzer (GUI)
        masscan # Fast port scanner
        rustscan # Fast port scanner written in Rust

        # Web application security
        nuclei # Fast vulnerability scanner
        nikto # Web server scanner
        dirb # Web content scanner
        gobuster # Directory/file/DNS busting tool
        ffuf # Fast web fuzzer
        httpx # Fast and multi-purpose HTTP toolkit
        subfinder # Subdomain discovery tool
        amass # Network mapping of attack surfaces

        # SSL/TLS analysis
        testssl # TLS/SSL testing tool
        sslscan # SSL cipher suite scanner
        sslyze # SSL/TLS scanning library

        # Password security tools (for authorized testing)
        hashcat # Advanced password recovery
        john # Password cracker
        hydra # Network login cracker
        medusa # Brute force authentication cracker

        # Code analysis and SAST
        semgrep # Static analysis tool
        bandit # Python security linter
        safety # Python dependency vulnerability checker
        checkov # Infrastructure as code scanner

        # Container and cloud security
        trivy # Comprehensive vulnerability scanner
        grype # Container vulnerability scanner
        docker-bench-security # Docker security benchmark

        # System analysis and forensics
        binwalk # Firmware analysis tool
        foremost # File recovery tool
        volatility3 # Memory forensics framework
        sleuthkit # File system forensic analysis

        # Network utilities
        dnsutils # DNS utilities
        whois # Domain information lookup
        dig # DNS lookup utility
        host # DNS lookup utility
        nslookup # DNS lookup utility

        # Monitoring and analysis
        lynis # System auditing tool
        chkrootkit # Rootkit checker
        rkhunter # Rootkit hunter

        # Development security tools
        gitleaks # Git secret scanner
        truffleHog # Search for secrets in git repositories

        # OSINT tools
        theHarvester # Email, subdomain and people names harvester
        recon-ng # Web reconnaissance framework

        # Wireless security (Linux only)
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        aircrack-ng # Wireless security auditing tools
        kismet # Wireless network detector
        wifite2 # Automated wireless attack tool
        hashcat-utils # Utilities for hashcat

        # Additional Linux-specific security tools
        yara # Pattern matching engine for malware research
        clamav # Antivirus engine
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific tools that work better natively
        darwin.apple_sdk.frameworks.Security
      ];

    # Environment variables for security tools
    home.sessionVariables = {
      # Nuclei configuration
      NUCLEI_TEMPLATES_PATH = "$HOME/.local/share/nuclei-templates";

      # Wordlists location
      WORDLISTS_PATH = "$HOME/.local/share/wordlists";

      # Output directory for security scan results
      SECURITY_RESULTS_PATH = "$HOME/.local/share/security-results";
    };

    # Create necessary directories
    home.activation.createSecurityDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p $HOME/.local/share/nuclei-templates
      mkdir -p $HOME/.local/share/wordlists
      mkdir -p $HOME/.local/share/security-results
      mkdir -p $HOME/.local/share/security-configs
    '';

    # Shell aliases for security operations
    home.shellAliases = {
      # Network scanning aliases
      "nmap-quick" = "nmap -T4 -F";
      "nmap-intense" = "nmap -T4 -A -v";
      "nmap-ping-sweep" = "nmap -sn";
      "nmap-tcp-syn" = "nmap -sS";
      "nmap-udp" = "nmap -sU --top-ports 1000";
      "nmap-vuln" = "nmap --script vuln";

      # Web application testing
      "nuclei-scan" = "nuclei -t ~/.local/share/nuclei-templates/";
      "nikto-scan" = "nikto -h";
      "dirb-common" = "dirb http:// /usr/share/dirb/wordlists/common.txt";
      "gobuster-dir" = "gobuster dir -u";
      "gobuster-dns" = "gobuster dns -d";

      # SSL/TLS testing
      "ssl-test" = "testssl --fast";
      "ssl-scan" = "sslscan";
      "ssl-analyze" = "sslyze --regular";

      # Password testing (authorized use only)
      "hashcat-md5" = "hashcat -m 0";
      "hashcat-sha1" = "hashcat -m 100";
      "hashcat-sha256" = "hashcat -m 1400";
      "john-crack" = "john --wordlist=/usr/share/wordlists/rockyou.txt";

      # Container security
      "trivy-image" = "trivy image";
      "trivy-fs" = "trivy fs";
      "grype-scan" = "grype";

      # System hardening
      "lynis-audit" = "sudo lynis audit system";
      "lynis-show" = "sudo lynis show";
      "chkrootkit-scan" = "sudo chkrootkit";
      "rkhunter-check" = "sudo rkhunter --check";

      # Code analysis
      "semgrep-scan" = "semgrep --config=auto";
      "bandit-scan" = "bandit -r";
      "safety-check" = "safety check";

      # Network utilities
      "ports-open" = "ss -tuln";
      "connections" = "ss -tulpn";
      "listening" = "ss -tln";

      # Quick security checks
      "sec-scan-host" = "nmap -sC -sV -O";
      "sec-scan-web" = "nikto -h";
      "sec-check-ssl" = "testssl --fast";
    };

    # Security scanning functions
    programs.zsh.initExtra = lib.mkIf (config.programs.zsh.enable or false) ''
            # Comprehensive network security scan
            function sec-scan-network() {
              local target="$1"
              if [[ -z "$target" ]]; then
                echo "Usage: sec-scan-network <target>"
                return 1
              fi

              local output_dir="$HOME/.local/share/security-results/$(date +%Y%m%d_%H%M%S)_$target"
              mkdir -p "$output_dir"

              echo "Starting comprehensive security scan of $target"
              echo "Results will be saved to: $output_dir"

              # Network discovery
              echo "=== Network Discovery ==="
              ${pkgs.nmap}/bin/nmap -sn "$target" | tee "$output_dir/discovery.txt"

              # Port scan
              echo "=== Port Scan ==="
              ${pkgs.nmap}/bin/nmap -sC -sV -O "$target" | tee "$output_dir/portscan.txt"

              # Vulnerability scan
              echo "=== Vulnerability Scan ==="
              ${pkgs.nmap}/bin/nmap --script vuln "$target" | tee "$output_dir/vulnscan.txt"

              echo "Scan complete. Results saved to $output_dir"
            }

            # Web application security scan
            function sec-scan-web() {
              local target="$1"
              if [[ -z "$target" ]]; then
                echo "Usage: sec-scan-web <target_url>"
                return 1
              fi

              local output_dir="$HOME/.local/share/security-results/web_$(date +%Y%m%d_%H%M%S)"
              mkdir -p "$output_dir"

              echo "Starting web application security scan of $target"
              echo "Results will be saved to: $output_dir"

              # Nikto scan
              echo "=== Nikto Scan ==="
              ${pkgs.nikto}/bin/nikto -h "$target" -o "$output_dir/nikto.txt"

              # Directory enumeration
              echo "=== Directory Enumeration ==="
              ${pkgs.gobuster}/bin/gobuster dir -u "$target" -w ${pkgs.seclists}/share/seclists/Discovery/Web-Content/common.txt -o "$output_dir/directories.txt"

              # Nuclei scan
              if command -v nuclei >/dev/null 2>&1; then
                echo "=== Nuclei Vulnerability Scan ==="
                ${pkgs.nuclei}/bin/nuclei -u "$target" -o "$output_dir/nuclei.txt"
              fi

              echo "Web scan complete. Results saved to $output_dir"
            }

            # SSL/TLS security analysis
            function sec-scan-ssl() {
              local target="$1"
              local port="''${2:-443}"

              if [[ -z "$target" ]]; then
                echo "Usage: sec-scan-ssl <target> [port]"
                return 1
              fi

              local output_dir="$HOME/.local/share/security-results/ssl_$(date +%Y%m%d_%H%M%S)"
              mkdir -p "$output_dir"

              echo "Starting SSL/TLS security analysis of $target:$port"
              echo "Results will be saved to: $output_dir"

              # testssl.sh comprehensive scan
              echo "=== TestSSL Analysis ==="
              ${pkgs.testssl}/bin/testssl --jsonfile "$output_dir/testssl.json" "$target:$port" | tee "$output_dir/testssl.txt"

              # sslscan
              echo "=== SSL Cipher Scan ==="
              ${pkgs.sslscan}/bin/sslscan "$target:$port" | tee "$output_dir/sslscan.txt"

              # sslyze
              echo "=== SSLyze Analysis ==="
              ${pkgs.sslyze}/bin/sslyze --regular "$target:$port" | tee "$output_dir/sslyze.txt"

              echo "SSL/TLS analysis complete. Results saved to $output_dir"
            }

            # Container security scan
            function sec-scan-container() {
              local image="$1"
              if [[ -z "$image" ]]; then
                echo "Usage: sec-scan-container <container_image>"
                return 1
              fi

              local output_dir="$HOME/.local/share/security-results/container_$(date +%Y%m%d_%H%M%S)"
              mkdir -p "$output_dir"

              echo "Starting container security scan of $image"
              echo "Results will be saved to: $output_dir"

              # Trivy scan
              echo "=== Trivy Vulnerability Scan ==="
              ${pkgs.trivy}/bin/trivy image --format json --output "$output_dir/trivy.json" "$image"
              ${pkgs.trivy}/bin/trivy image "$image" | tee "$output_dir/trivy.txt"

              # Grype scan
              if command -v grype >/dev/null 2>&1; then
                echo "=== Grype Vulnerability Scan ==="
                ${pkgs.grype}/bin/grype "$image" -o json > "$output_dir/grype.json"
                ${pkgs.grype}/bin/grype "$image" | tee "$output_dir/grype.txt"
              fi

              echo "Container security scan complete. Results saved to $output_dir"
            }

            # System hardening check
            function sec-check-system() {
              local output_dir="$HOME/.local/share/security-results/system_$(date +%Y%m%d_%H%M%S)"
              mkdir -p "$output_dir"

              echo "Starting system security audit"
              echo "Results will be saved to: $output_dir"

              # Lynis system audit
              if command -v lynis >/dev/null 2>&1; then
                echo "=== Lynis System Audit ==="
                sudo ${pkgs.lynis}/bin/lynis audit system --logfile "$output_dir/lynis.log" | tee "$output_dir/lynis.txt"
              fi

              # Check for rootkits
              if command -v chkrootkit >/dev/null 2>&1; then
                echo "=== Rootkit Check ==="
                sudo ${pkgs.chkrootkit}/bin/chkrootkit | tee "$output_dir/chkrootkit.txt"
              fi

              # RKHunter scan
              if command -v rkhunter >/dev/null 2>&1; then
                echo "=== RKHunter Scan ==="
                sudo ${pkgs.rkhunter}/bin/rkhunter --check --sk --logfile "$output_dir/rkhunter.log" | tee "$output_dir/rkhunter.txt"
              fi

              echo "System security audit complete. Results saved to $output_dir"
            }

            # Code security analysis
            function sec-scan-code() {
              local target="''${1:-.}"
              local output_dir="$HOME/.local/share/security-results/code_$(date +%Y%m%d_%H%M%S)"
              mkdir -p "$output_dir"

              echo "Starting code security analysis of $target"
              echo "Results will be saved to: $output_dir"

              # Semgrep scan
              if command -v semgrep >/dev/null 2>&1; then
                echo "=== Semgrep Static Analysis ==="
                ${pkgs.semgrep}/bin/semgrep --config=auto --json --output="$output_dir/semgrep.json" "$target"
                ${pkgs.semgrep}/bin/semgrep --config=auto "$target" | tee "$output_dir/semgrep.txt"
              fi

              # Python-specific analysis
              if [[ -f "$target/requirements.txt" || -f "$target/pyproject.toml" ]]; then
                echo "=== Python Security Analysis ==="

                # Bandit for Python code
                if command -v bandit >/dev/null 2>&1; then
                  ${pkgs.bandit}/bin/bandit -r "$target" -f json -o "$output_dir/bandit.json"
                  ${pkgs.bandit}/bin/bandit -r "$target" | tee "$output_dir/bandit.txt"
                fi

                # Safety for dependencies
                if command -v safety >/dev/null 2>&1 && [[ -f "$target/requirements.txt" ]]; then
                  ${pkgs.safety}/bin/safety check -r "$target/requirements.txt" --json --output "$output_dir/safety.json"
                  ${pkgs.safety}/bin/safety check -r "$target/requirements.txt" | tee "$output_dir/safety.txt"
                fi
              fi

              # Git secrets scan
              if command -v gitleaks >/dev/null 2>&1 && [[ -d "$target/.git" ]]; then
                echo "=== Git Secrets Scan ==="
                ${pkgs.gitleaks}/bin/gitleaks detect --source "$target" --report-format json --report-path "$output_dir/gitleaks.json"
                ${pkgs.gitleaks}/bin/gitleaks detect --source "$target" | tee "$output_dir/gitleaks.txt"
              fi

              echo "Code security analysis complete. Results saved to $output_dir"
            }

            # Update security tools and databases
            function sec-update() {
              echo "Updating security tools and databases..."

              # Update Nuclei templates
              if command -v nuclei >/dev/null 2>&1; then
                echo "Updating Nuclei templates..."
                ${pkgs.nuclei}/bin/nuclei -update-templates -silent
              fi

              # Update Trivy database
              if command -v trivy >/dev/null 2>&1; then
                echo "Updating Trivy database..."
                ${pkgs.trivy}/bin/trivy image --download-db-only
              fi

              echo "Security tools updated successfully"
            }

            # Generate security report
            function sec-report() {
              local target="$1"
              if [[ -z "$target" ]]; then
                echo "Usage: sec-report <target_host_or_url>"
                return 1
              fi

              local timestamp=$(date +%Y%m%d_%H%M%S)
              local output_dir="$HOME/.local/share/security-results/comprehensive_''${timestamp}_$(echo $target | tr '/' '_')"
              mkdir -p "$output_dir"

              echo "Generating comprehensive security report for $target"
              echo "This may take a while..."
              echo "Results will be saved to: $output_dir"

              # Create report summary
              cat > "$output_dir/README.md" << EOF
      # Security Assessment Report

      **Target:** $target
      **Date:** $(date)
      **Generated by:** $(whoami)

      ## Scan Components

      - Network Discovery and Port Scanning
      - Vulnerability Assessment
      - Web Application Security Testing
      - SSL/TLS Configuration Analysis
      - Container Security (if applicable)

      ## Files Generated

      - \`network/\` - Network scanning results
      - \`web/\` - Web application testing results
      - \`ssl/\` - SSL/TLS analysis results
      - \`summary.txt\` - Executive summary

      EOF

              # Run comprehensive scans
              mkdir -p "$output_dir/network" "$output_dir/web" "$output_dir/ssl"

              # Network scan
              echo "Running network security scan..."
              ${pkgs.nmap}/bin/nmap -sC -sV -O "$target" > "$output_dir/network/detailed_scan.txt" 2>&1
              ${pkgs.nmap}/bin/nmap --script vuln "$target" > "$output_dir/network/vulnerability_scan.txt" 2>&1

              # If target looks like a URL, run web scans
              if [[ "$target" =~ ^https?:// ]]; then
                echo "Running web application security scan..."
                ${pkgs.nikto}/bin/nikto -h "$target" -o "$output_dir/web/nikto_scan.txt" 2>&1

                # Extract hostname for SSL testing
                local hostname=$(echo "$target" | sed -E 's|^https?://([^/]+).*|\1|')
                echo "Running SSL/TLS security analysis..."
                ${pkgs.testssl}/bin/testssl "$hostname" > "$output_dir/ssl/testssl_analysis.txt" 2>&1
              fi

              # Generate summary
              echo "Generating executive summary..."
              cat > "$output_dir/summary.txt" << EOF
      Security Assessment Summary
      ==========================
      Target: $target
      Date: $(date)

      High-level findings will be summarized here after manual review of detailed results.

      Next Steps:
      1. Review detailed scan results in subdirectories
      2. Prioritize findings based on risk level
      3. Develop remediation plan for critical issues
      4. Schedule follow-up testing after remediation

      EOF

              echo ""
              echo "Comprehensive security report complete!"
              echo "Report location: $output_dir"
              echo "Review the README.md file for an overview of generated files"
            }
    '';

    # Bash functions (similar structure)
    programs.bash.initExtra = lib.mkIf (config.programs.bash.enable or false) ''
      # Quick security scan function
      function sec-quick-scan() {
        local target="$1"
        if [[ -z "$target" ]]; then
          echo "Usage: sec-quick-scan <target>"
          return 1
        fi

        echo "Quick security scan of $target"
        echo "=== Port Scan ==="
        ${pkgs.nmap}/bin/nmap -T4 -F "$target"

        echo "=== Service Detection ==="
        ${pkgs.nmap}/bin/nmap -sV --top-ports 100 "$target"

        if [[ "$target" =~ ^https?:// ]]; then
          echo "=== Quick Web Scan ==="
          ${pkgs.nikto}/bin/nikto -h "$target" -Tuning x 6
        fi
      }

      # Update security databases
      function sec-update() {
        echo "Updating security tool databases..."
        if command -v nuclei >/dev/null 2>&1; then
          ${pkgs.nuclei}/bin/nuclei -update-templates -silent
        fi
        if command -v trivy >/dev/null 2>&1; then
          ${pkgs.trivy}/bin/trivy image --download-db-only
        fi
        echo "Updates complete"
      }
    '';

    # Configuration files for security tools
    xdg.configFile = {
      # Nuclei configuration
      "nuclei/config.yaml".text = ''
        # Nuclei configuration
        templates-directory: ~/.local/share/nuclei-templates
        output-directory: ~/.local/share/security-results
        header:
          - "User-Agent: Mozilla/5.0 (compatible; Security-Scanner/1.0)"
        rate-limit: 150
        bulk-size: 25
        timeout: 10
        retries: 1
        severity: info,low,medium,high,critical
      '';

      # Nmap scripts configuration
      "nmap/nmap-scripts.conf".text = ''
        # Custom Nmap scripts configuration
        # Add custom script configurations here
      '';
    };

    # VSCode extensions for security development (if VSCode is enabled)
    programs.vscode.extensions = lib.mkIf (config.programs.vscode.enable or false) (with pkgs.vscode-extensions; [
      # Security-focused extensions
      ms-python.python # For Python security analysis
      ms-vscode.vscode-json # For JSON analysis of security reports
      redhat.vscode-yaml # For YAML security configs
      timonwong.shellcheck # Shell script security analysis
    ]);
  };

  # Darwin (macOS) system configuration
  flake.modules.darwin.securityTools = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # macOS system packages for security tools
    environment.systemPackages = with pkgs; [
      # Network analysis (macOS compatible)
      nmap # Network mapper
      netcat-gnu # Network utility
      wireshark # Network analyzer (works on macOS)

      # SSL/TLS analysis
      testssl # TLS/SSL testing
      sslscan # SSL cipher scanner
      sslyze # SSL analysis library

      # Web security tools
      nuclei # Vulnerability scanner
      gobuster # Directory/DNS busting tool

      # Container security
      trivy # Container vulnerability scanner
      grype # Container vulnerability scanner

      # Code analysis
      semgrep # Static analysis tool
      gitleaks # Git secrets scanner

      # System analysis
      lynis # Security auditing tool

      # Password tools (for authorized testing)
      hashcat # Password recovery
      john # Password cracker

      # Forensics and analysis
      binwalk # Firmware analysis
      volatility3 # Memory forensics

      # Network utilities
      dnsutils # DNS tools
      whois # Domain lookup
      curl # HTTP client
    ];

    # macOS-specific security tools via Homebrew
    homebrew = {
      brews = [
        "nikto" # Web server scanner
        "hydra" # Network login cracker
        "dirb" # Web content scanner
        "masscan" # Fast port scanner
        "aircrack-ng" # Wireless security tools
        "tcpdump" # Packet analyzer
        "netcat" # Network utility
      ];

      casks = [
        "wireshark" # Network protocol analyzer GUI
        "burp-suite" # Web security testing platform
        "owasp-zap" # Web application security scanner
        "metasploit" # Penetration testing framework
      ];
    };

    # macOS security configurations
    system.defaults = {
      # Security-focused system defaults
      NSGlobalDomain = {
        # Require password after screensaver/sleep
        NSRequiresAquaSystemAppearance = false;
      };

      # Secure screensaver settings
      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 0;
      };

      # Security and privacy settings
      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
    };

    # Security services and configurations
    environment.variables = {
      # Set paths for security tools
      NUCLEI_TEMPLATES_PATH = "/Users/$(whoami)/.local/share/nuclei-templates";
      SECURITY_RESULTS_PATH = "/Users/$(whoami)/.local/share/security-results";
    };
  };
}
