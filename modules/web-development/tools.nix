# Web development CLI tools and user environment
# Contains packages, aliases, environment variables, and development utilities
# Available on all platforms: NixOS, Darwin, and Home Manager
_: {
  # NixOS system configuration - CLI tools only
  flake.modules.nixos.webDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.features.webDev;
  in {
    options.features.webDev = {
      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Additional web development packages to install system-wide";
      };
    };

    config = {
      # System packages for web development tools
      environment.systemPackages = with pkgs;
        [
          # SSL certificate management
          openssl
          mkcert

          # System monitoring tools
          nettools
          lsof
          tcpdump
        ]
        ++ cfg.extraPackages;
    };
  };

  # Darwin (macOS) system configuration
  flake.modules.darwin.webDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Install web development tools via Homebrew (better integration on macOS)
    homebrew = {
      brews = [
        "mkcert" # SSL certificate generation
        "nss" # Network Security Services (for mkcert)
      ];

      casks = [
        # Browsers for testing
        "google-chrome"
        "firefox"
        "firefox-developer-edition"
        "safari-technology-preview"

        # Development tools
        "insomnia" # API testing
        "proxyman" # HTTP debugging proxy
        "responsively" # Responsive web design testing

        # Productivity
        "imageoptim" # Image optimization
        "colorpicker-skala" # Color picker tool
      ];
    };

    # System packages for web development on macOS
    environment.systemPackages = with pkgs; [
      # Command-line tools that work well via Nix on macOS
      httpie
      curl
      jq
      watchman # File watching service

      # Image processing
      imagemagick
      optipng
      jpegoptim

      # Development utilities
      gh # GitHub CLI
      git-lfs
    ];

    # macOS-specific web development environment
    environment.variables = {
      # Optimize for development
      HOMEBREW_NO_AUTO_UPDATE = "1";

      # Browser automation
      PUPPETEER_SKIP_CHROMIUM_DOWNLOAD = "true";
      PUPPETEER_EXECUTABLE_PATH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
    };

    # System defaults optimized for web development
    system.defaults = {
      # Dock configuration
      dock.autohide = true;
      dock.show-recents = false;

      # Finder configuration for web assets
      finder.AppleShowAllExtensions = true;
      finder.ShowPathbar = true;
      finder.ShowStatusBar = true;

      # Performance optimizations
      NSGlobalDomain.NSWindowResizeTime = 0.001;
    };
  };

  # Home Manager user configuration
  flake.modules.homeModules.webDevelopment = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs;
      [
        # Node.js ecosystem
        nodejs_22
        npm
        yarn
        pnpm
        nodePackages.npx

        # Modern JavaScript runtimes
        bun
        deno

        # Frontend build tools
        nodePackages.webpack
        nodePackages.webpack-cli
        vite
        parcel
        rollup

        # CSS preprocessing and tools
        sass
        nodePackages.postcss
        nodePackages.postcss-cli
        nodePackages.autoprefixer

        # Code quality and formatting
        nodePackages.eslint
        nodePackages.prettier
        nodePackages.stylelint
        nodePackages.typescript
        nodePackages.typescript-language-server

        # Testing frameworks
        playwright-driver
        nodePackages.cypress

        # Build and bundling tools
        esbuild
        nodePackages.swc

        # Static site generators
        hugo
        jekyll
        zola

        # Development servers and utilities
        nodePackages.serve
        nodePackages.browser-sync
        nodePackages.live-server

        # API development and testing
        insomnia
        httpie
        curl
        jq

        # Web scraping and automation
        nodePackages.puppeteer

        # Package management utilities
        nodePackages.npm-check-updates
        nodePackages.depcheck
        nodePackages.npm-run-all
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        # Linux-specific packages
        google-chrome # For testing
        firefox-devedition-bin
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        # macOS-specific packages handled via homebrew in darwin module
      ];

    # Development environment variables
    home.sessionVariables = {
      # Node.js configuration
      NODE_ENV = lib.mkDefault "development";
      NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";

      # Enable better stack traces
      NODE_OPTIONS = "--enable-source-maps";

      # Bun configuration
      BUN_INSTALL = "${config.home.homeDirectory}/.bun";

      # Deno configuration
      DENO_INSTALL = "${config.home.homeDirectory}/.deno";
    };

    # Add various package manager bins to PATH
    home.sessionPath = [
      "${config.home.homeDirectory}/.npm-global/bin"
      "${config.home.homeDirectory}/.bun/bin"
      "${config.home.homeDirectory}/.deno/bin"
    ];

    # Shell aliases for web development
    home.shellAliases = {
      # Package management shortcuts
      ni = "npm install";
      nr = "npm run";
      ns = "npm start";
      nt = "npm test";
      nb = "npm run build";
      nd = "npm run dev";
      nci = "npm ci";
      ncu = "npm-check-updates";

      # Yarn shortcuts
      yi = "yarn install";
      yr = "yarn run";
      ys = "yarn start";
      yt = "yarn test";
      yb = "yarn build";
      yd = "yarn dev";

      # pnpm shortcuts
      pni = "pnpm install";
      pnr = "pnpm run";
      pns = "pnpm start";
      pnt = "pnpm test";
      pnb = "pnpm build";
      pnd = "pnpm dev";

      # Bun shortcuts
      bi = "bun install";
      br = "bun run";
      bs = "bun start";
      bt = "bun test";
      bb = "bun build";
      bd = "bun dev";

      # Development servers
      serve-here = "serve -s . -p 8000";
      serve-spa = "serve -s build -p 8080";
      live-reload = "live-server --port=8000";

      # Quick project creation
      create-react = "npx create-react-app";
      create-next = "npx create-next-app";
      create-vue = "npm init vue@latest";
      create-vite = "npm create vite@latest";

      # Testing shortcuts
      e2e-test = "npx playwright test";
      cypress-run = "npx cypress run";
      cypress-open = "npx cypress open";

      # Build tool shortcuts
      webpack-dev = "npx webpack serve --mode development";
      vite-dev = "npx vite";
      vite-build = "npx vite build";
      vite-preview = "npx vite preview";

      # Utility shortcuts
      format-js = "prettier --write '**/*.{js,jsx,ts,tsx,json,css,md}'";
      lint-js = "eslint --fix '**/*.{js,jsx,ts,tsx}'";
      check-deps = "depcheck";

      # Local SSL certificate generation
      mkcert-dev = "mkcert localhost 127.0.0.1 ::1";
    };

    # Git configuration for web development
    programs.git.extraConfig = {
      # Ignore common web development files
      core.excludesFile = pkgs.writeText "web-gitignore" ''
        # Dependencies
        node_modules/
        npm-debug.log*
        yarn-debug.log*
        yarn-error.log*
        .pnpm-debug.log*
        .yarn/

        # Build outputs
        dist/
        build/
        .next/
        .nuxt/
        .vuepress/dist/
        .docusaurus/

        # Environment files
        .env.local
        .env.development.local
        .env.test.local
        .env.production.local

        # IDE files
        .vscode/
        .idea/
        *.swp
        *.swo

        # OS files
        .DS_Store
        Thumbs.db
      '';
    };

    # VSCode extensions for web development (if VSCode is enabled)
    programs.vscode.extensions = lib.mkIf (config.programs.vscode.enable or false) (with pkgs.vscode-extensions; [
      # Language support
      bradlc.vscode-tailwindcss
      ms-vscode.vscode-typescript-next
      ms-vscode.vscode-json

      # Frameworks
      ms-vscode.vscode-node-debug2
      formulahendry.auto-rename-tag
      christian-kohler.path-intellisense

      # Formatting and linting
      esbenp.prettier-vscode
      dbaeumer.vscode-eslint
      stylelint.vscode-stylelint

      # Git integration
      eamodio.gitlens

      # Productivity
      ms-vscode-remote.remote-ssh
      ms-vscode.vscode-json
    ]);

    # Zsh functions for project scaffolding
    programs.zsh.initExtra = lib.mkAfter ''
      # Quick project scaffolding functions
      web-project() {
        local project_name="$1"
        local template="$2"

        if [[ -z "$project_name" ]]; then
          echo "Usage: web-project <project-name> [template]"
          echo "Templates: react, next, vue, vite, express, fastify"
          return 1
        fi

        case "$template" in
          "react")
            npx create-react-app "$project_name"
            ;;
          "next")
            npx create-next-app "$project_name"
            ;;
          "vue")
            npm init vue@latest "$project_name"
            ;;
          "vite")
            npm create vite@latest "$project_name"
            ;;
          "express")
            mkdir "$project_name" && cd "$project_name"
            npm init -y
            npm install express
            ;;
          "fastify")
            mkdir "$project_name" && cd "$project_name"
            npm init -y
            npm install fastify
            ;;
          *)
            mkdir "$project_name" && cd "$project_name"
            npm init -y
            ;;
        esac
      }

      # Quick development server function
      dev-serve() {
        local port="''${1:-8000}"
        local dir="''${2:-.}"

        if command -v bun >/dev/null; then
          bun --bun serve "$dir" --port "$port"
        elif command -v deno >/dev/null; then
          deno run --allow-net --allow-read https://deno.land/std/http/file_server.ts --port "$port" "$dir"
        else
          npx serve -s "$dir" -p "$port"
        fi
      }

      # SSL certificate generation for development
      dev-ssl() {
        local domain="''${1:-localhost}"
        if command -v mkcert >/dev/null; then
          mkcert "$domain"
          echo "SSL certificate generated for $domain"
          echo "cert.pem and key.pem created in current directory"
        else
          echo "mkcert not found. Install it first: brew install mkcert (macOS) or nix-shell -p mkcert"
        fi
      }
    '';
  };
}
