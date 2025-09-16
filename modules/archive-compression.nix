_: {
  flake.modules.nixos.archiveCompression = {
    pkgs,
    lib,
    ...
  }: {
    # System-level archive and compression tools
    environment.systemPackages = with pkgs; [
      # Archive formats
      gnutar
      zip
      unzip
      p7zip
      unrar

      # Compression algorithms
      gzip
      bzip2
      xz
      zstd
      lz4

      # Advanced archive tools
      atool
      dtrx
      unar
      lrzip

      # Verification tools
      par2cmdline
      rhash

      # GUI tools
      file-roller

      # Backup tools
      restic
      borgbackup
      rclone

      # Split/join utilities
      coreutils # provides split and cat
    ];

    # Enable compression support for various services
    boot.supportedFilesystems = ["squashfs"];

    # System-wide shell aliases for archive operations
    environment.shellAliases = {
      # Quick extraction
      "extract" = "dtrx";
      "x" = "dtrx";

      # Archive creation shortcuts
      "mktar" = "tar -czf";
      "mkzip" = "zip -r";
      "mk7z" = "7z a";

      # Verification shortcuts
      "checksum" = "rhash --all";
      "verify-par2" = "par2 verify";
    };

    # Configure file associations for archive types
    environment.etc."mime.types".text = ''
      application/x-7z-compressed	7z
      application/x-bzip2		bz2
      application/x-compress		Z
      application/x-gzip		gz
      application/x-lzip		lz
      application/x-lzma		lzma
      application/x-rar-compressed	rar
      application/x-tar		tar
      application/x-xz		xz
      application/zip			zip
      application/x-zstd		zst
    '';
  };

  flake.modules.darwin.archiveCompression = {
    pkgs,
    lib,
    ...
  }: {
    # macOS system-level archive and compression tools
    environment.systemPackages = with pkgs;
      [
        # Archive formats (excluding macOS built-ins)
        p7zip
        unrar

        # Compression algorithms
        zstd
        lz4
        lrzip

        # Advanced archive tools
        atool
        dtrx
        unar

        # Verification tools
        par2cmdline
        rhash

        # Backup tools
        restic
        borgbackup
        rclone

        # Split/join utilities
        coreutils # provides split and cat
      ]
      ++ lib.optionals (!pkgs.stdenv.hostPlatform.isAarch64) [
        # Intel-specific packages if needed
      ];

    # macOS-specific configuration
    system.defaults.NSGlobalDomain = {
      # Enable better archive handling in Finder
      AppleShowAllExtensions = true;
    };

    # Homebrew casks for GUI tools
    homebrew.casks = [
      "keka" # Advanced archive manager
      "the-unarchiver" # Universal archive extractor
    ];

    # System-wide shell aliases for archive operations
    environment.shellAliases = {
      # Quick extraction
      "extract" = "dtrx";
      "x" = "dtrx";

      # Archive creation shortcuts
      "mktar" = "tar -czf";
      "mkzip" = "zip -r";
      "mk7z" = "7z a";

      # Verification shortcuts
      "checksum" = "rhash --all";
      "verify-par2" = "par2 verify";

      # macOS-specific
      "spotlight-reindex" = "sudo mdutil -E /";
    };
  };

  flake.modules.homeModules.archiveCompression = {
    pkgs,
    lib,
    config,
    ...
  }: {
    # User-level archive and compression tools and configuration
    home.packages = with pkgs;
      [
        # Core archive tools (user preferences)
        gnutar
        zip
        unzip
        p7zip

        # Compression algorithms
        gzip
        bzip2
        xz
        zstd
        lz4

        # Advanced tools
        atool # Archive tool wrapper
        dtrx # Intelligent archive extraction
        unar # Universal unarchiver
        lrzip # Long Range ZIP

        # Verification and integrity
        par2cmdline # PAR2 redundancy
        rhash # Hash calculation

        # Backup solutions
        restic # Modern backup program
        borgbackup # Deduplicating backup
        rclone # Cloud storage sync

        # Additional utilities
        file # File type detection
        tree # Directory tree display
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific packages
        file-roller # GNOME archive manager
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific packages
      ];

    # Shell configuration for archive operations
    programs.bash.shellAliases = {
      # Smart extraction
      "extract" = "dtrx";
      "x" = "dtrx";

      # Archive creation with sensible defaults
      "mktar" = "tar -czf";
      "mktarbz2" = "tar -cjf";
      "mktarxz" = "tar -cJf";
      "mktarzst" = "tar -c --zstd -f";
      "mkzip" = "zip -r";
      "mk7z" = "7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on";

      # Quick compression
      "gzit" = "gzip -9";
      "bzit" = "bzip2 -9";
      "xzit" = "xz -9";
      "zstdit" = "zstd -19";

      # Verification
      "checksum" = "rhash --all";
      "sha256sum" = "rhash --sha256";
      "md5sum" = "rhash --md5";
      "verify-par2" = "par2 verify";
      "create-par2" = "par2 create -r5";

      # Backup shortcuts
      "backup-restic" = "restic backup";
      "backup-borg" = "borg create";
      "sync-rclone" = "rclone sync";

      # Archive listing
      "lstar" = "tar -tzf";
      "lszip" = "unzip -l";
      "ls7z" = "7z l";
      "lsrar" = "unrar l";
    };

    programs.zsh.shellAliases = {
      # Smart extraction
      "extract" = "dtrx";
      "x" = "dtrx";

      # Archive creation with sensible defaults
      "mktar" = "tar -czf";
      "mktarbz2" = "tar -cjf";
      "mktarxz" = "tar -cJf";
      "mktarzst" = "tar -c --zstd -f";
      "mkzip" = "zip -r";
      "mk7z" = "7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on";

      # Quick compression
      "gzit" = "gzip -9";
      "bzit" = "bzip2 -9";
      "xzit" = "xz -9";
      "zstdit" = "zstd -19";

      # Verification
      "checksum" = "rhash --all";
      "sha256sum" = "rhash --sha256";
      "md5sum" = "rhash --md5";
      "verify-par2" = "par2 verify";
      "create-par2" = "par2 create -r5";

      # Backup shortcuts
      "backup-restic" = "restic backup";
      "backup-borg" = "borg create";
      "sync-rclone" = "rclone sync";

      # Archive listing
      "lstar" = "tar -tzf";
      "lszip" = "unzip -l";
      "ls7z" = "7z l";
      "lsrar" = "unrar l";
    };

    programs.fish = lib.mkIf config.programs.fish.enable {
      shellAliases = {
        # Smart extraction
        "extract" = "dtrx";
        "x" = "dtrx";

        # Archive creation with sensible defaults
        "mktar" = "tar -czf";
        "mktarbz2" = "tar -cjf";
        "mktarxz" = "tar -cJf";
        "mktarzst" = "tar -c --zstd -f";
        "mkzip" = "zip -r";
        "mk7z" = "7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on";

        # Quick compression
        "gzit" = "gzip -9";
        "bzit" = "bzip2 -9";
        "xzit" = "xz -9";
        "zstdit" = "zstd -19";

        # Verification
        "checksum" = "rhash --all";
        "sha256sum" = "rhash --sha256";
        "md5sum" = "rhash --md5";
        "verify-par2" = "par2 verify";
        "create-par2" = "par2 create -r5";

        # Backup shortcuts
        "backup-restic" = "restic backup";
        "backup-borg" = "borg create";
        "sync-rclone" = "rclone sync";

        # Archive listing
        "lstar" = "tar -tzf";
        "lszip" = "unzip -l";
        "ls7z" = "7z l";
        "lsrar" = "unrar l";
      };

      functions = {
        # Smart extraction function with automatic format detection
        extract_auto = {
          description = "Smart extraction with automatic format detection";
          body = ''
            if test (count $argv) -eq 0
              echo "Usage: extract_auto <archive_file> [destination]"
              return 1
            end

            set archive $argv[1]
            set dest $argv[2]

            if test -z "$dest"
              set dest (basename $archive | sed 's/\.[^.]*$//')
            end

            switch (string lower (path extension $archive))
              case '.tar.gz' '.tgz'
                tar -xzf $archive -C $dest
              case '.tar.bz2' '.tbz2'
                tar -xjf $archive -C $dest
              case '.tar.xz' '.txz'
                tar -xJf $archive -C $dest
              case '.tar.zst'
                tar --zstd -xf $archive -C $dest
              case '.zip'
                unzip $archive -d $dest
              case '.7z'
                7z x $archive -o$dest
              case '.rar'
                unrar x $archive $dest/
              case '.gz'
                gunzip -c $archive > $dest
              case '.bz2'
                bunzip2 -c $archive > $dest
              case '.xz'
                unxz -c $archive > $dest
              case '.zst'
                zstd -d $archive -o $dest
              case '*'
                echo "Unsupported archive format: $archive"
                return 1
            end
          '';
        };

        # Create compressed archives with optimal settings
        mkarchive = {
          description = "Create compressed archives with optimal settings";
          body = ''
            if test (count $argv) -lt 2
              echo "Usage: mkarchive <format> <output> <input...>"
              echo "Formats: tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z"
              return 1
            end

            set format $argv[1]
            set output $argv[2]
            set -e argv[1..2]

            switch $format
              case 'tar.gz'
                tar -czf $output $argv
              case 'tar.bz2'
                tar -cjf $output $argv
              case 'tar.xz'
                tar -cJf $output $argv
              case 'tar.zst'
                tar -c --zstd -f $output $argv
              case 'zip'
                zip -r $output $argv
              case '7z'
                7z a -t7z -m0=lzma2 -mx=9 $output $argv
              case '*'
                echo "Unsupported format: $format"
                return 1
            end
          '';
        };

        # Backup functions
        quick_backup = {
          description = "Quick backup using restic";
          body = ''
            if test -z "$RESTIC_REPOSITORY"
              echo "Please set RESTIC_REPOSITORY environment variable"
              return 1
            end

            if test (count $argv) -eq 0
              set argv $HOME
            end

            restic backup --verbose $argv
          '';
        };
      };
    };

    # Archive-related environment variables
    home.sessionVariables = {
      # Default compression levels
      GZIP = "-9";
      BZIP2 = "-9";
      XZ_OPT = "-9";
      ZSTD_CLEVEL = "19";

      # Archive extraction preferences
      DTRX_EXTRACT_DIR = "$HOME/Downloads/extracted";
      ATOOL_EXTRACT_DIR = "$HOME/Downloads/extracted";
    };

    # XDG MIME associations for archive types
    xdg.mimeApps = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      defaultApplications = {
        "application/x-7z-compressed" = ["org.gnome.FileRoller.desktop"];
        "application/x-bzip2" = ["org.gnome.FileRoller.desktop"];
        "application/x-compress" = ["org.gnome.FileRoller.desktop"];
        "application/x-gzip" = ["org.gnome.FileRoller.desktop"];
        "application/x-rar-compressed" = ["org.gnome.FileRoller.desktop"];
        "application/x-tar" = ["org.gnome.FileRoller.desktop"];
        "application/x-xz" = ["org.gnome.FileRoller.desktop"];
        "application/zip" = ["org.gnome.FileRoller.desktop"];
        "application/x-zstd" = ["org.gnome.FileRoller.desktop"];
      };
    };

    # Configuration files for archive tools
    home.file = {
      ".config/atool/atoolrc" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        text = ''
          # Atool configuration
          use_arc_subdir_auto yes
          extract_dir $HOME/Downloads/extracted
          add_compression_level 9
        '';
      };
    };

    # Git configuration for archive handling
    programs.git = lib.mkIf config.programs.git.enable {
      extraConfig = {
        # Configure Git to handle archives better
        tar = {
          "tar.gz" = "gzip -cn";
          "tar.bz2" = "bzip2 -c";
          "tar.xz" = "xz -c";
          "tar.zst" = "zstd -c";
        };
      };
    };
  };
}
