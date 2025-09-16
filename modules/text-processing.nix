_: {
  flake.modules.nixos.textProcessing = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # System-level text processing tools and system integration
    environment.systemPackages = with pkgs; [
      # Traditional text editors
      nano
      vim
      emacs-nox # Emacs without X11 dependencies
      micro

      # Core text processing utilities
      gnused # Stream editor
      gawk # GNU awk
      gnugrep # GNU grep
      coreutils # sort, uniq, cut, tr, wc
      diffutils # diff, cmp, comm

      # Modern alternatives
      ripgrep # Modern grep replacement
      fd # Modern find replacement
      bat # Modern cat replacement
      choose # Modern cut/awk alternative
      sd # Modern sed replacement

      # Text analysis tools
      file # File type detection

      # JSON/YAML processing
      jq # JSON processor
      yq-go # YAML processor
      gron # Make JSON greppable
      fx # JSON viewer and processor

      # CSV/TSV processing
      xsv # CSV toolkit
      miller # Data processing tool for CSV/TSV/JSON
      visidata # Interactive data explorer

      # Regular expression tools
      pcre # Perl Compatible Regular Expressions
      pcregrep # grep with PCRE support

      # Text transformation
      dos2unix # Convert line endings
      recode # Character set conversion
      iconv # Character encoding conversion

      # Templating engines
      envsubst # Environment variable substitution
      gomplate # Template processor
    ];

    # System-wide editor configuration
    environment.variables = {
      EDITOR = lib.mkDefault "vim";
      VISUAL = lib.mkDefault "vim";
      PAGER = lib.mkDefault "less";
    };

    # Enable locate database for file searching
    services.locate.enable = true;
    services.locate.package = pkgs.mlocate;
    services.locate.interval = "hourly";
  };

  flake.modules.darwin.textProcessing = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # macOS system text processing packages
    environment.systemPackages = with pkgs; [
      # Text editors (prefer native macOS integration)
      nano
      vim
      micro

      # Core utilities (GNU versions for consistency)
      gnused
      gawk
      gnugrep
      coreutils
      diffutils

      # Modern alternatives
      ripgrep
      fd
      bat
      choose
      sd

      # Text analysis
      file

      # JSON/YAML processing
      jq
      yq-go
      gron
      fx

      # CSV/TSV processing
      xsv
      miller
      visidata

      # Regular expressions
      pcre
      pcregrep

      # Text transformation
      dos2unix
      recode

      # Templating
      envsubst
      gomplate
    ];

    # System environment variables
    environment.variables = {
      EDITOR = lib.mkDefault "vim";
      VISUAL = lib.mkDefault "vim";
      PAGER = lib.mkDefault "less";
    };

    # macOS-specific text tools via Homebrew
    homebrew.brews = [
      "grep" # GNU grep (as backup)
      "gnu-sed" # GNU sed (as backup)
      "mustache" # Mustache templating
    ];

    homebrew.casks = [
      "emacs" # GUI Emacs for macOS
      "textmate" # Native macOS text editor
    ];

    # Enable locate equivalent on macOS
    system.defaults.finder.FXEnableExtensionChangeWarning = false;
  };

  flake.modules.homeModules.textProcessing = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # User-level text processing tools and configurations
    home.packages = with pkgs;
      [
        # Text editors
        nano
        vim
        emacs-nox
        micro

        # Traditional text processing
        gnused
        gawk
        gnugrep
        coreutils
        diffutils

        # Modern alternatives
        ripgrep
        fd
        bat
        choose
        sd

        # Text analysis
        file

        # JSON/YAML processing
        jq
        yq-go
        gron
        fx

        # CSV/TSV processing
        xsv
        miller
        visidata

        # Regular expressions
        pcre
        pcregrep

        # Text transformation
        dos2unix
        recode

        # Templating
        envsubst
        gomplate
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific text tools
        csvkit # Python CSV toolkit
        iconv # Character encoding conversion
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific or enhanced tools
        # (most tools work cross-platform)
      ];

    # Editor environment variables
    home.sessionVariables = {
      EDITOR = lib.mkDefault "vim";
      VISUAL = lib.mkDefault "vim";
      PAGER = lib.mkDefault "less";
      LESS = "-R --use-color -Dd+r -Du+b"; # Color support for less
      RIPGREP_CONFIG_PATH = "${config.xdg.configHome}/ripgrep/config";
    };

    # Shell aliases for text operations
    programs.zsh.shellAliases = lib.mkIf (config.programs.zsh.enable or false) {
      # Modern alternatives
      "cat" = "bat";
      "grep" = "rg";
      "find" = "fd";

      # Text processing shortcuts
      "jsonpp" = "jq '.'"; # Pretty-print JSON
      "yamlpp" = "yq eval '.' -P"; # Pretty-print YAML
      "csv" = "xsv"; # CSV toolkit
      "data" = "visidata"; # Interactive data explorer

      # Common text operations
      "lines" = "wc -l"; # Count lines
      "chars" = "wc -c"; # Count characters
      "words" = "wc -w"; # Count words
      "unique" = "sort | uniq"; # Unique lines
      "count-unique" = "sort | uniq -c"; # Count unique lines
      "remove-empty" = "grep -v '^$'"; # Remove empty lines
      "trim" = "sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"; # Trim whitespace

      # File type detection
      "filetype" = "file -b"; # Brief file type
      "mime" = "file -b --mime-type"; # MIME type

      # Text transformation
      "to-unix" = "dos2unix"; # Convert to Unix line endings
      "to-dos" = "unix2dos"; # Convert to DOS line endings
      "to-lower" = "tr '[:upper:]' '[:lower:]'"; # Convert to lowercase
      "to-upper" = "tr '[:lower:]' '[:upper:]'"; # Convert to uppercase

      # Quick searches
      "search-text" = "rg -i"; # Case-insensitive search
      "search-files" = "fd -t f"; # Search for files
      "search-dirs" = "fd -t d"; # Search for directories
    };

    programs.bash.shellAliases = lib.mkIf (config.programs.bash.enable or false) {
      # Modern alternatives
      "cat" = "bat";
      "grep" = "rg";
      "find" = "fd";

      # Text processing shortcuts
      "jsonpp" = "jq '.'";
      "yamlpp" = "yq eval '.' -P";
      "csv" = "xsv";
      "data" = "visidata";

      # Common text operations
      "lines" = "wc -l";
      "chars" = "wc -c";
      "words" = "wc -w";
      "unique" = "sort | uniq";
      "count-unique" = "sort | uniq -c";
      "remove-empty" = "grep -v '^$'";
      "trim" = "sed 's/^[[:space:]]*//;s/[[:space:]]*$//'";

      # File type detection
      "filetype" = "file -b";
      "mime" = "file -b --mime-type";

      # Text transformation
      "to-unix" = "dos2unix";
      "to-dos" = "unix2dos";
      "to-lower" = "tr '[:upper:]' '[:lower:]'";
      "to-upper" = "tr '[:lower:]' '[:upper:]'";

      # Quick searches
      "search-text" = "rg -i";
      "search-files" = "fd -t f";
      "search-dirs" = "fd -t d";
    };

    # Text processing functions for shell integration
    programs.zsh.initExtra = lib.mkIf (config.programs.zsh.enable or false) ''
      # Text processing pipeline functions

      # Extract specific columns from text
      function extract-column() {
        local column=''${1:-1}
        local delimiter=''${2:-' '}
        cut -d"$delimiter" -f"$column"
      }

      # Find and replace in files
      function find-replace() {
        if [ $# -lt 2 ]; then
          echo "Usage: find-replace <pattern> <replacement> [files...]"
          return 1
        fi
        local pattern="$1"
        local replacement="$2"
        shift 2

        if [ $# -eq 0 ]; then
          # Use current directory if no files specified
          ${pkgs.sd}/bin/sd "$pattern" "$replacement" **/*
        else
          ${pkgs.sd}/bin/sd "$pattern" "$replacement" "$@"
        fi
      }

      # Convert between different data formats
      function convert-data() {
        local from_format="$1"
        local to_format="$2"
        local input_file="$3"

        case "$from_format-$to_format" in
          "csv-json")
            ${pkgs.xsv}/bin/xsv fmt --out-delimiter=, "$input_file" | ${pkgs.miller}/bin/mlr --icsv --ojson cat
            ;;
          "json-csv")
            ${pkgs.jq}/bin/jq -r '(.[0] | keys_unsorted) as $keys | $keys, map([.[ $keys[] ]])[] | @csv' "$input_file"
            ;;
          "yaml-json")
            ${pkgs.yq-go}/bin/yq eval -o=json "$input_file"
            ;;
          "json-yaml")
            ${pkgs.yq-go}/bin/yq eval -P "$input_file"
            ;;
          *)
            echo "Unsupported conversion: $from_format -> $to_format"
            echo "Supported: csv-json, json-csv, yaml-json, json-yaml"
            return 1
            ;;
        esac
      }

      # Text analysis pipeline
      function analyze-text() {
        local file="$1"
        if [ -z "$file" ]; then
          echo "Usage: analyze-text <file>"
          return 1
        fi

        echo "=== Text Analysis for $file ==="
        echo
        echo "File type: $(${pkgs.file}/bin/file -b "$file")"
        echo "File size: $(du -h "$file" | cut -f1)"
        echo "Lines: $(wc -l < "$file")"
        echo "Words: $(wc -w < "$file")"
        echo "Characters: $(wc -c < "$file")"
        echo
        echo "=== Top 10 most frequent words ==="
        tr '[:space:]' '\n' < "$file" | \
          tr '[:upper:]' '[:lower:]' | \
          sed 's/[^a-z]//g' | \
          grep -v '^$' | \
          sort | uniq -c | sort -nr | head -10
      }

      # CSV/TSV analysis
      function analyze-csv() {
        local file="$1"
        if [ -z "$file" ]; then
          echo "Usage: analyze-csv <file>"
          return 1
        fi

        echo "=== CSV Analysis for $file ==="
        echo
        echo "Columns: $(${pkgs.xsv}/bin/xsv headers "$file" | wc -l)"
        echo "Rows: $(${pkgs.xsv}/bin/xsv count "$file")"
        echo
        echo "=== Column Headers ==="
        ${pkgs.xsv}/bin/xsv headers "$file"
        echo
        echo "=== Data Types ==="
        ${pkgs.xsv}/bin/xsv stats "$file" | ${pkgs.xsv}/bin/xsv select field,type
        echo
        echo "=== Sample Data (first 5 rows) ==="
        ${pkgs.xsv}/bin/xsv slice -l 5 "$file" | ${pkgs.xsv}/bin/xsv table
      }

      # JSON processing utilities
      function json-keys() {
        local file="$1"
        if [ -z "$file" ]; then
          ${pkgs.jq}/bin/jq -r 'keys[]'
        else
          ${pkgs.jq}/bin/jq -r 'keys[]' "$file"
        fi
      }

      function json-paths() {
        local file="$1"
        if [ -z "$file" ]; then
          ${pkgs.jq}/bin/jq -r 'paths(scalars) as $p | $p | join(".")'
        else
          ${pkgs.jq}/bin/jq -r 'paths(scalars) as $p | $p | join(".")' "$file"
        fi
      }

      # Text transformation pipeline
      function text-pipeline() {
        echo "Text Processing Pipeline"
        echo "Input: $1"
        echo "Available transformations:"
        echo "  1. Remove empty lines"
        echo "  2. Trim whitespace"
        echo "  3. Convert to lowercase"
        echo "  4. Convert to uppercase"
        echo "  5. Remove duplicate lines"
        echo "  6. Sort lines"
        echo "  7. Number lines"
        echo "  8. Word count"
        echo "  9. Character frequency"
        echo "Enter comma-separated numbers (e.g., 1,2,5): "

        read -r transformations
        local input="$1"
        local temp_file=$(mktemp)
        cp "$input" "$temp_file"

        IFS=',' read -ra TRANSFORMS <<< "$transformations"
        for transform in "''${TRANSFORMS[@]}"; do
          case "''${transform// /}" in
            1) grep -v '^$' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" ;;
            2) sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" ;;
            3) tr '[:upper:]' '[:lower:]' < "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" ;;
            4) tr '[:lower:]' '[:upper:]' < "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" ;;
            5) sort -u "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" ;;
            6) sort "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" ;;
            7) cat -n "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file" ;;
            8) echo "Word count: $(wc -w < "$temp_file")" ;;
            9) fold -w1 < "$temp_file" | sort | uniq -c | sort -nr | head -10 ;;
          esac
        done

        echo "=== Result ==="
        cat "$temp_file"
        rm "$temp_file"
      }
    '';

    programs.bash.initExtra = lib.mkIf (config.programs.bash.enable or false) ''
      # Text processing pipeline functions (bash version)

      extract-column() {
        local column=''${1:-1}
        local delimiter=''${2:-' '}
        cut -d"$delimiter" -f"$column"
      }

      find-replace() {
        if [ $# -lt 2 ]; then
          echo "Usage: find-replace <pattern> <replacement> [files...]"
          return 1
        fi
        local pattern="$1"
        local replacement="$2"
        shift 2

        if [ $# -eq 0 ]; then
          ${pkgs.sd}/bin/sd "$pattern" "$replacement" **/*
        else
          ${pkgs.sd}/bin/sd "$pattern" "$replacement" "$@"
        fi
      }

      analyze-text() {
        local file="$1"
        if [ -z "$file" ]; then
          echo "Usage: analyze-text <file>"
          return 1
        fi

        echo "=== Text Analysis for $file ==="
        echo
        echo "File type: $(${pkgs.file}/bin/file -b "$file")"
        echo "File size: $(du -h "$file" | cut -f1)"
        echo "Lines: $(wc -l < "$file")"
        echo "Words: $(wc -w < "$file")"
        echo "Characters: $(wc -c < "$file")"
        echo
        echo "=== Top 10 most frequent words ==="
        tr '[:space:]' '\n' < "$file" | \
          tr '[:upper:]' '[:lower:]' | \
          sed 's/[^a-z]//g' | \
          grep -v '^$' | \
          sort | uniq -c | sort -nr | head -10
      }

      json-keys() {
        local file="$1"
        if [ -z "$file" ]; then
          ${pkgs.jq}/bin/jq -r 'keys[]'
        else
          ${pkgs.jq}/bin/jq -r 'keys[]' "$file"
        fi
      }
    '';

    # Configuration files for text processing tools

    # Ripgrep configuration
    xdg.configFile."ripgrep/config".text = ''
      # Ripgrep configuration
      --max-columns=150
      --max-columns-preview
      --smart-case
      --hidden
      --glob=!.git/*
      --glob=!node_modules/*
      --glob=!.npm/*
      --glob=!.cache/*
      --colors=line:none
      --colors=line:style:bold
      --colors=path:fg:green
      --colors=match:fg:black
      --colors=match:bg:yellow
    '';

    # Bat configuration
    programs.bat = {
      enable = true;
      config = {
        theme = "TwoDark";
        style = "numbers,changes,header";
        pager = "less -FR";
        map-syntax = [
          "*.jenkinsfile:Groovy"
          "*.props:Java Properties"
        ];
      };
    };

    # Micro editor configuration
    xdg.configFile."micro/settings.json".text = builtins.toJSON {
      autoclose = true;
      autoindent = true;
      autosave = false;
      basename = false;
      colorscheme = "default";
      cursorline = true;
      eofnewline = true;
      fastdirty = true;
      fileformat = "unix";
      ignorecase = false;
      indentchar = " ";
      infobar = true;
      keepautoindent = false;
      keymenu = false;
      mouse = true;
      pluginchannels = [
        "https://raw.githubusercontent.com/micro-editor/plugin-channel/master/channel.json"
      ];
      pluginrepos = [];
      rmtrailingws = false;
      ruler = true;
      savecursor = false;
      savehistory = true;
      saveundo = false;
      scrollbar = false;
      scrollmargin = 3;
      scrollspeed = 2;
      softwrap = false;
      splitbottom = true;
      splitright = true;
      statusformatl = "$(filename) $(modified)($(line),$(col)) $(status.paste)| ft:$(opt:filetype) | $(opt:fileformat) | $(opt:encoding)";
      statusformatr = "$(bind:ToggleKeyMenu): bindings, $(bind:ToggleHelp): help";
      statusline = true;
      syntax = true;
      tabmovement = false;
      tabsize = 4;
      tabstospaces = false;
      termtitle = false;
      wordwrap = false;
    };

    # Visidata configuration for data exploration
    xdg.configFile."visidata/config.py".text = ''
      # Visidata configuration for data exploration
      from visidata import *

      # Color scheme
      options.color_default = 'white'
      options.color_key_col = 'bold'
      options.color_selected_row = 'reverse'

      # Display options
      options.disp_float_fmt = '{:.2f}'
      options.disp_int_fmt = '{:,}'
      options.disp_date_fmt = '%Y-%m-%d'

      # CSV options
      options.csv_delimiter = ','
      options.csv_quotechar = '"'
      options.csv_skipinitialspace = True

      # JSON options
      options.json_indent = 2
      options.json_sort_keys = False

      # Excel options
      options.xlsx_meta_columns = False

      # Performance
      options.async_load = True
      options.min_memory_mb = 0
    '';

    # JQ configuration for JSON processing
    home.sessionVariables.JQ_COLORS = "0;90:0;37:0;37:0;37:0;32:1;37:1;37";

    # Environment for text processing tools
    home.sessionVariables = {
      # CSV/TSV processing
      XSV_DEFAULT_DELIMITER = ",";
      MILLER_CSV_DEFAULT_RS = "lf";

      # Text editors
      MICRO_CONFIG_HOME = "${config.xdg.configHome}/micro";

      # Paging and display
      MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
      MANROFFOPT = "-c";
    };
  };
}
