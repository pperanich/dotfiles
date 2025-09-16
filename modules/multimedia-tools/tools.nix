_: {
  # NixOS system-level multimedia tools (CLI and GUI packages only)
  flake.modules.nixos.multimediaTools = {pkgs, ...}: {
    # System packages for multimedia processing and playback
    environment.systemPackages = with pkgs; [
      # Video processing and conversion
      ffmpeg-full # Complete multimedia framework with all codecs
      yt-dlp # Download videos from YouTube and many other sites
      mpv # Lightweight, powerful video player
      vlc # Cross-platform multimedia player
      handbrake # Video transcoder
      mkvtoolnix # Matroska tools for working with MKV files

      # Audio processing and conversion
      sox # Swiss army knife of sound processing
      lame # High quality MPEG Audio Layer III encoder
      flac # Free Lossless Audio Codec
      opus-tools # Opus codec tools
      mediainfo # Display technical and tag data for media files

      # Image processing and manipulation
      imagemagick # Image manipulation suite
      gimp # GNU Image Manipulation Program
      inkscape # Vector graphics editor
      optipng # PNG optimizer
      jpegoptim # JPEG optimization utility

      # Streaming and recording
      obs-studio # Video recording and streaming
      streamlink # CLI for extracting streams from streaming services

      # Metadata tools
      exiftool # Read and write meta information in files
      kid3 # ID3 tag editor

      # Professional 3D creation
      blender # 3D creation suite
    ];

    # Enable additional multimedia codecs and formats
    nixpkgs.config.allowUnfree = true;
  };

  # Home Manager user-level multimedia tools and configuration
  flake.modules.homeModules.multimediaTools = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (config.home) homeDirectory;

    # Common video conversion functions for shell integration
    videoConversionFunctions = {
      convert-to-mp4 = ''
        function convert-to-mp4() {
          local input="$1"
          local output="''${2:-''${input%.*}.mp4}"
          ffmpeg -i "$input" -c:v libx264 -crf 23 -c:a aac -b:a 128k "$output"
        }
      '';

      compress-video = ''
        function compress-video() {
          local input="$1"
          local output="''${2:-compressed_''${input}}"
          local crf="''${3:-28}"
          ffmpeg -i "$input" -c:v libx264 -crf "$crf" -c:a aac -b:a 96k "$output"
        }
      '';

      extract-audio = ''
        function extract-audio() {
          local input="$1"
          local output="''${2:-''${input%.*}.mp3}"
          ffmpeg -i "$input" -vn -c:a mp3 -b:a 192k "$output"
        }
      '';

      batch-resize-images = ''
        function batch-resize-images() {
          local size="''${1:-1920x1080}"
          local quality="''${2:-85}"
          mkdir -p resized
          for img in *.{jpg,jpeg,png,JPG,JPEG,PNG}; do
            [[ -f "$img" ]] || continue
            magick "$img" -resize "$size>" -quality "$quality" "resized/$img"
          done
        }
      '';

      optimize-images = ''
        function optimize-images() {
          for img in *.jpg *.jpeg *.JPG *.JPEG; do
            [[ -f "$img" ]] || continue
            jpegoptim --max=85 "$img"
          done
          for img in *.png *.PNG; do
            [[ -f "$img" ]] || continue
            optipng -o2 "$img"
          done
        }
      '';
    };

    # Common aliases for multimedia operations
    multimediaAliases = {
      # Video processing shortcuts
      "yt-mp3" = "yt-dlp --extract-audio --audio-format mp3 --audio-quality 0";
      "yt-mp4" = "yt-dlp -f 'best[height<=1080]' --merge-output-format mp4";
      "yt-best" = "yt-dlp -f bestvideo+bestaudio --merge-output-format mkv";

      # Media information
      "mediainfo-short" = "mediainfo --Output=General;%Format%,%FileSize/String%,%Duration/String% --Output=Video;%Format%,%Width%x%Height%,%FrameRate% --Output=Audio;%Format%,%Channels%ch,%SamplingRate/String%";
      "ffprobe-short" = "ffprobe -v quiet -print_format json -show_format -show_streams";

      # Image processing
      "img-resize" = "magick mogrify -resize";
      "img-quality" = "magick mogrify -quality";

      # Audio processing
      "audio-normalize" = "sox -v 0.95";
      "audio-trim" = "sox";

      # Quick conversions
      "to-webp" = "magick convert -quality 80 -define webp:lossless=false";
      "to-avif" = "magick convert -quality 80";
    };
  in {
    home.packages = with pkgs;
      [
        # Video processing and conversion
        ffmpeg-full
        yt-dlp
        mpv
        vlc
        handbrake
        mkvtoolnix

        # Audio processing
        sox
        lame
        flac
        opus-tools
        mediainfo
        audacity

        # Image processing
        imagemagick
        gimp
        inkscape
        optipng
        jpegoptim

        # Streaming and recording
        obs-studio
        streamlink

        # Metadata tools
        exiftool
        kid3

        # Additional user-space tools
        kdenlive # Video editor
        krita # Digital painting
        darktable # Photo workflow
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific multimedia tools
        openshot-qt # Video editor
        pitivi # Video editor
        cheese # Webcam tool
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific multimedia tools (Nix packages where available)
      ];

    # Shell integration for multimedia workflows
    programs.zsh = {
      shellAliases = multimediaAliases;
      initExtra = ''
        ${lib.concatStringsSep "\n" (lib.attrValues videoConversionFunctions)}
      '';
    };

    programs.bash = {
      shellAliases = multimediaAliases;
      bashrcExtra = ''
        ${lib.concatStringsSep "\n" (lib.attrValues videoConversionFunctions)}
      '';
    };

    # Media directories configuration
    xdg.userDirs = {
      enable = true;
      videos = "${homeDirectory}/Videos";
      pictures = "${homeDirectory}/Pictures";
      music = "${homeDirectory}/Music";
    };

    # Application-specific configurations
    programs.mpv = {
      enable = true;
      config = {
        # Hardware acceleration
        hwdec = "auto-safe";
        vo = "gpu";
        profile = "gpu-hq";

        # Audio
        audio-file-auto = "fuzzy";
        audio-pitch-correction = "yes";

        # Subtitles
        sub-auto = "fuzzy";
        # sub-file-paths-append = "ass";
        # sub-file-paths-append = "srt";
        # sub-file-paths-append = "sub";
        # sub-file-paths-append = "subs";
        # sub-file-paths-append = "subtitles";

        # Interface
        osd-playing-msg = "Playing: \${filename}";
        term-osd-bar = "yes";

        # Performance
        cache = "yes";
        demuxer-max-bytes = "150MiB";
        demuxer-max-back-bytes = "75MiB";
      };
    };

    # Home directory structure for multimedia workflow
    home.file = {
      ".config/obs-studio/basic/profiles/Default/basic.ini".text = ''
        [General]
        Name=Default

        [Video]
        BaseCX=1920
        BaseCY=1080
        OutputCX=1920
        OutputCY=1080
        FPSType=0
        FPSNum=30
        FPSden=1

        [Audio]
        SampleRate=44100
        ChannelSetup=Stereo
      '';

      "Scripts/multimedia/.keep".text = "";
    };
  };

  # Darwin system-level multimedia tools with Metal and VideoToolbox integration
  flake.modules.darwin.multimediaTools = {pkgs, ...}: {
    # System packages optimized for macOS
    environment.systemPackages = with pkgs; [
      # Core multimedia tools with macOS optimizations
      ffmpeg-full
      yt-dlp
      mpv
      handbrake

      # Audio tools
      sox
      lame
      flac
      opus-tools
      mediainfo

      # Image processing
      imagemagick
      optipng
      jpegoptim

      # Command-line tools that work well on macOS
      exiftool
      streamlink
    ];

    # macOS-specific multimedia environment variables
    environment.variables = {
      # Enable VideoToolbox hardware acceleration
      FFMPEG_CAPTURE_METHOD = "avfoundation";
      # OpenGL context for multimedia applications
      MESA_GL_VERSION_OVERRIDE = "4.1";
    };

    # Homebrew casks for GUI multimedia applications
    homebrew.casks = [
      # Professional video editing and processing
      "final-cut-pro" # Apple's professional video editor (if licensed)
      "adobe-premiere-pro" # Adobe's video editor (subscription)
      "davinci-resolve" # Professional color correction and editing
      "compressor" # Apple's video compression tool

      # Audio applications
      "logic-pro" # Apple's professional audio editor (if licensed)
      "audacity" # Open-source audio editor
      "reaper" # Digital audio workstation
      "soundsource" # Audio routing and enhancement

      # Image and graphics applications
      "adobe-photoshop" # Industry standard image editor (subscription)
      "adobe-illustrator" # Vector graphics editor (subscription)
      "pixelmator-pro" # Mac-native image editor
      "affinity-photo" # Professional photo editing
      "affinity-designer" # Vector graphics design
      "sketch" # UI/UX design tool

      # Video conversion and compression
      "handbrake" # Video transcoder with GUI
      "subler" # MP4 muxer and subtitle editor
      "video-converter-elmedia" # Video format converter

      # Streaming and recording
      "obs" # Open Broadcaster Software
      "loom" # Screen recording and sharing
      "cleanshot" # Screenshot and annotation tool
      "keka" # Archive utility for media files

      # Metadata and organization
      "exifrenamer" # Rename photos based on EXIF data
      "phototheater-pro" # Photo management and editing
      "music-converter-pro" # Audio format converter

      # 3D and animation
      "blender" # Open-source 3D creation suite
      "cinema-4d" # Professional 3D modeling (if licensed)

      # Media players with enhanced codec support
      "vlc" # Universal media player
      "iina" # Modern macOS media player
      "quicktime-player" # Apple's media player (usually pre-installed)
    ];

    # Homebrew taps for multimedia applications
    homebrew.taps = [
      "homebrew/cask"
      "homebrew/cask-drivers" # For multimedia device drivers
    ];

    # Additional Homebrew packages for multimedia development
    homebrew.brews = [
      "ffmpeg" # With additional codec support
      "imagemagick" # With all delegates enabled
      "libheif" # HEIF/HEIC image support
      "x264" # H.264/MPEG-4 AVC encoder
      "x265" # H.265/HEVC encoder
      "opus" # Opus codec
      "webp" # WebP image support
    ];

    # macOS system preferences for multimedia workflows
    system.defaults = {
      # Finder preferences for media files
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      # Enable media key functionality
      NSGlobalDomain = {
        "com.apple.mouse.tapBehavior" = 1;
        AppleKeyboardUIMode = 3;
      };
    };
  };
}
