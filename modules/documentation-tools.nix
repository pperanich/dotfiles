_: {
  # NixOS system-level documentation tools
  flake.modules.nixos.documentationTools = {pkgs, ...}: {
    # System-level documentation processing with full font and library support
    environment.systemPackages = with pkgs; [
      # PDF generation dependencies requiring system libraries
      wkhtmltopdf
      weasyprint

      # System fonts for document rendering
      dejavu_fonts
      liberation_ttf
      unifont

      # LaTeX for high-quality document typesetting
      texlive.combined.scheme-full

      # Graphviz for system-wide diagram generation
      graphviz-nox

      # PlantUML with Java runtime
      plantuml
      openjdk

      # System-level calibre for ebook management
      calibre

      # Sphinx with system Python dependencies
      python3Packages.sphinx
      python3Packages.sphinx-rtd-theme
      python3Packages.recommonmark

      # System-wide Asciidoc processing
      asciidoc-full
      asciidoctor
    ];

    # System fonts configuration for document rendering
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      source-han-sans
      source-han-serif
    ];

    # System environment variables for documentation tools
    environment.variables = {
      PLANTUML_JAR = "${pkgs.plantuml}/lib/plantuml.jar";
    };

    # Enable system services for documentation processing
    services.postgresql.enable = true; # For outline and other wiki tools
    services.redis.servers."docs-cache" = {
      enable = true;
      port = 6380;
    };
  };

  # Home Manager user-level documentation environment
  flake.modules.homeModules.documentationTools = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.home) homeDirectory;

    # Custom scripts for documentation workflows
    docScripts = pkgs.writeShellScriptBin "doc-scripts" ''
      # Documentation workflow functions

      # Generate site with Hugo
      hugo-new() {
        if [ -z "$1" ]; then
          echo "Usage: hugo-new <site-name>"
          return 1
        fi
        ${pkgs.hugo}/bin/hugo new site "$1"
        cd "$1" && git init
      }

      # Build and serve documentation
      docs-serve() {
        if [ -f "mkdocs.yml" ]; then
          ${pkgs.mkdocs}/bin/mkdocs serve
        elif [ -f "docusaurus.config.js" ]; then
          ${pkgs.nodejs}/bin/npm start
        elif [ -f "config.toml" ] || [ -f "config.yaml" ]; then
          ${pkgs.hugo}/bin/hugo server -D
        elif [ -f "book.toml" ]; then
          ${pkgs.mdbook}/bin/mdbook serve
        else
          echo "No supported documentation framework detected"
          return 1
        fi
      }

      # Convert documents with pandoc
      pandoc-convert() {
        if [ $# -lt 3 ]; then
          echo "Usage: pandoc-convert <input-file> <output-file> <format>"
          return 1
        fi
        ${pkgs.pandoc}/bin/pandoc "$1" -o "$2" --to="$3" --standalone
      }

      # Generate PDF with puppeteer
      pdf-generate() {
        if [ -z "$1" ]; then
          echo "Usage: pdf-generate <url-or-html-file> [output.pdf]"
          return 1
        fi
        local output="''${2:-document.pdf}"
        ${pkgs.nodePackages.puppeteer-cli}/bin/puppeteer print "$1" "$output"
      }

      # Create presentation from markdown
      slides-create() {
        if [ -z "$1" ]; then
          echo "Usage: slides-create <markdown-file> [theme]"
          return 1
        fi
        local theme="''${2:-white}"
        ${pkgs.nodePackages.reveal-md}/bin/reveal-md "$1" --theme "$theme"
      }

      # Lint markdown files
      md-lint() {
        local files="''${@:-.}"
        ${pkgs.markdownlint-cli}/bin/markdownlint "$files"
      }

      # Generate table of contents for markdown
      md-toc() {
        if [ -z "$1" ]; then
          echo "Usage: md-toc <markdown-file>"
          return 1
        fi
        ${pkgs.nodePackages.markdown-toc}/bin/markdown-toc -i "$1"
      }

      # Convert diagram code to images
      diagram-render() {
        if [ $# -lt 2 ]; then
          echo "Usage: diagram-render <type> <input-file> [output-format]"
          echo "Types: mermaid, plantuml, graphviz"
          return 1
        fi

        local type="$1"
        local input="$2"
        local format="''${3:-png}"
        local output="''${input%.*}.$format"

        case "$type" in
          mermaid)
            ${pkgs.nodePackages.mermaid-cli}/bin/mmdc -i "$input" -o "$output"
            ;;
          plantuml)
            ${pkgs.plantuml}/bin/plantuml -t"$format" "$input"
            ;;
          graphviz|dot)
            ${pkgs.graphviz}/bin/dot -T"$format" "$input" -o "$output"
            ;;
          *)
            echo "Unknown diagram type: $type"
            return 1
            ;;
        esac
      }

      # Export aliases and functions
      export -f hugo-new docs-serve pandoc-convert pdf-generate slides-create
      export -f md-lint md-toc diagram-render
    '';
  in {
    home.packages = with pkgs;
      [
        # Static site generators
        hugo
        jekyll
        zola
        mkdocs

        # Markdown tools
        pandoc
        markdownlint-cli
        nodePackages.markdown-toc

        # Documentation frameworks
        python3Packages.sphinx
        python3Packages.sphinx-rtd-theme
        python3Packages.mkdocs-material
        gitbook-cli
        mdbook

        # Diagram tools
        graphviz
        plantuml
        nodePackages.mermaid-cli

        # PDF generation
        wkhtmltopdf
        weasyprint
        nodePackages.puppeteer-cli

        # Presentation tools
        nodePackages.reveal-md
        nodePackages.marp-cli
        slides

        # API documentation
        redoc-cli
        swagger-ui
        docusaurus

        # Wiki tools
        tiddlywiki
        # outline # Not available in nixpkgs

        # Writing and editing
        vale
        alex

        # Conversion tools
        calibre
        asciidoc
        asciidoctor

        # Custom workflow scripts
        docScripts
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        # macOS-specific documentation apps
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        # Linux-specific tools
        libreoffice
        evince # PDF viewer
      ];

    # Program configurations
    programs = {
      # Git configuration for documentation projects
      git.includes = [
        {
          condition = "gitdir:**/docs/";
          contents = {
            user.name = "Documentation Bot";
            commit.template = "${homeDirectory}/.config/git/docs-commit-template";
          };
        }
      ];
    };

    # XDG configuration files
    xdg.configFile = {
      # Vale style configuration
      "vale/.vale.ini".text = ''
        StylesPath = styles

        MinAlertLevel = suggestion

        Packages = Microsoft, write-good, alex

        [*]
        BasedOnStyles = Vale, Microsoft, write-good

        [*.md]
        BasedOnStyles = Vale, Microsoft, write-good, alex
      '';

      # Markdownlint configuration
      "markdownlint/.markdownlintrc".text = builtins.toJSON {
        default = true;
        MD013 = {line_length = 100;};
        MD033 = false; # Allow HTML
        MD041 = false; # First line in file should be a top level header
      };

      # MkDocs template
      "mkdocs/mkdocs-template.yml".text = ''
        site_name: Documentation Site
        site_description: Generated with Nix documentation tools

        theme:
          name: material
          features:
            - navigation.tabs
            - navigation.sections
            - toc.integrate
            - search.highlight

        plugins:
          - search
          - awesome-pages

        markdown_extensions:
          - admonition
          - codehilite
          - toc:
              permalink: true
          - pymdownx.superfences:
              custom_fences:
                - name: mermaid
                  class: mermaid
                  format: !!python/name:pymdownx.superfences.fence_code_format
      '';

      # Hugo archetype
      "hugo/archetypes/default.md".text = ''
        ---
        title: "{{ replace .Name "-" " " | title }}"
        date: {{ .Date }}
        draft: true
        tags: []
        categories: []
        ---

        <!-- Content goes here -->
      '';

      # Reveal.js theme configuration
      "reveal-md/theme.json".text = builtins.toJSON {
        theme = "white";
        highlightTheme = "github";
        transition = "slide";
        transitionSpeed = "default";
        backgroundTransition = "fade";
      };
    };

    # Shell aliases for documentation workflows
    programs.zsh.shellAliases = {
      # Site generators
      "hugo-serve" = "hugo server -D --bind 0.0.0.0";
      "jekyll-serve" = "bundle exec jekyll serve --host 0.0.0.0";
      "zola-serve" = "zola serve --interface 0.0.0.0";
      "mkdocs-serve" = "mkdocs serve --dev-addr 0.0.0.0:8000";

      # Documentation building
      "docs-build" = "docs-serve";
      "site-build" = "docs-serve";

      # Markdown processing
      "md2pdf" = "pandoc-convert";
      "md2html" = ''pandoc --to html5 --standalone --highlight-style pygments'';
      "md2docx" = ''pandoc --to docx'';

      # Presentation shortcuts
      "slides-serve" = "reveal-md --watch";
      "marp-serve" = "marp --server --watch";

      # Linting shortcuts
      "lint-md" = "markdownlint";
      "lint-prose" = "vale";
      "lint-docs" = "markdownlint . && vale .";

      # Diagram generation
      "mermaid-render" = "mmdc";
      "plantuml-render" = "plantuml";
      "dot-render" = "dot -Tpng";

      # API documentation
      "swagger-serve" = "swagger-ui-serve";
      "redoc-serve" = "redoc-cli serve";

      # Quick document conversion
      "html2pdf" = "wkhtmltopdf";
      "url2pdf" = "wkhtmltopdf";
    };

    # Environment variables for documentation tools
    home.sessionVariables = {
      HUGO_CACHEDIR = "${config.xdg.cacheHome}/hugo";
      MKDOCS_CONFIG_FILE = "${config.xdg.configHome}/mkdocs/mkdocs-template.yml";
      VALE_CONFIG_PATH = "${config.xdg.configHome}/vale/.vale.ini";
      PANDOC_DATA_DIR = "${config.xdg.dataHome}/pandoc";

      # Diagram tools
      PLANTUML_JAR = "${pkgs.plantuml}/lib/plantuml.jar";
      GRAPHVIZ_DOT = "${pkgs.graphviz}/bin/dot";

      # PDF generation
      PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
    };

    # Home directory structure for documentation projects
    home.file = {
      "Documents/templates/hugo/.gitkeep".text = "";
      "Documents/templates/mkdocs/.gitkeep".text = "";
      "Documents/templates/mdbook/.gitkeep".text = "";
      "Documents/diagrams/.gitkeep".text = "";

      # Git commit template for documentation
      ".config/git/docs-commit-template".text = ''
        # Documentation update

        # Type of change:
        # docs: documentation changes
        # content: content updates
        # style: formatting, typos
        # structure: reorganization
        # assets: images, diagrams

        # Affected sections:

        # Details:
      '';
    };
  };

  # Darwin system-level documentation tools
  flake.modules.darwin.documentationTools = {
    pkgs,
    config,
    ...
  }: {
    # macOS system packages for documentation
    environment.systemPackages = with pkgs; [
      # Core documentation tools that integrate with macOS
      pandoc
      graphviz
      plantuml
      wkhtmltopdf

      # Native macOS font support
      darwin.apple_sdk.frameworks.CoreText
    ];

    # macOS-specific environment variables
    environment.variables = {
      # Path to system fonts for document rendering
      FONTCONFIG_PATH = "/System/Library/Fonts:/Library/Fonts";

      # PDF generation with system fonts
      WKHTMLTOPDF_OPTIONS = "--enable-local-file-access";
    };

    # Homebrew packages for macOS-native documentation apps
    homebrew = {
      taps = ["homebrew/cask-fonts"];

      casks = [
        # Documentation and writing apps
        "obsidian" # Note-taking and knowledge management
        "notion" # All-in-one workspace
        "typora" # Markdown editor
        "marked" # Markdown preview
        "macdown" # Markdown editor
        "zettelkasten" # Note-taking

        # PDF and document tools
        "pdf-expert" # PDF editing
        "papers" # Research paper management
        "devonthink" # Document management

        # Diagram and visualization
        "omnigraffle" # Diagramming
        "lucidchart" # Online diagramming
        "mindnode" # Mind mapping

        # Fonts for documentation
        "font-source-code-pro"
        "font-fira-code"
        "font-jetbrains-mono"
        "font-computer-modern"
      ];

      brews = [
        # CLI documentation tools that work better via Homebrew on macOS
        "pandoc-crossref" # Pandoc filter for cross-references
        "hugo" # Sometimes newer versions available

        # macOS-specific tools
        "pdfgrep" # Search in PDFs
      ];
    };

    # macOS system configuration for documentation
    system.defaults = {
      # Finder settings for documentation projects
      finder = {
        ShowExternalHardDrivesOnDesktop = true;
        ShowRemovableMediaOnDesktop = true;
      };

      # Quick Look plugins for documentation formats
      dock.persistent-apps = [
        "/Applications/Obsidian.app"
        "/Applications/Typora.app"
      ];
    };

    # Launch agents for documentation services
    launchd.user.agents.documentation-watcher = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.fswatch}/bin/fswatch"
          "-o"
          "${config.users.users.peranpl1.home}/Documents"
          "--event-flags"
        ];
        RunAtLoad = false;
        KeepAlive = false;
      };
    };
  };
}
