_: {
  # Web-based network scanner UI (scanservjs) backed by sane-airscan.
  # Pulls scans from any AirScan/eSCL device and saves to a configurable output dir.
  flake.modules.nixos.scanservjs =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.scanservjs;

      # Optional sane-airscan pin: builds a tiny "backend" derivation whose
      # etc/sane.d/airscan.conf overrides the upstream default. mkSaneConfig
      # processes extraBackends last and ln -sfn lets the last copy win.
      airscanOverlay =
        if cfg.scanner.url == null then
          null
        else
          pkgs.runCommand "sane-airscan-pinned" { } ''
            mkdir -p $out/etc/sane.d
            cat > $out/etc/sane.d/airscan.conf <<EOF
            [options]
            discovery = ${if cfg.scanner.discovery then "enable" else "disable"}

            [devices]
            "${cfg.scanner.name}" = ${cfg.scanner.url}
            EOF
          '';
    in
    {
      options.my.scanservjs = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 8080;
          description = "Port for scanservjs web UI";
        };
        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address for scanservjs to bind to";
        };
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Open the configured TCP port in the host firewall";
        };
        outputDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/scanservjs/data/output";
          description = "Directory where finished scans are written (must be writable by scanservjs user)";
        };
        scanner = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "Network Scanner";
            description = "Friendly name for the pinned scanner (only used when scanner.url is set)";
          };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "http://10.0.20.50/eSCL";
            description = ''
              Pin a specific eSCL/AirScan device URL. When null, sane-airscan
              relies on mDNS discovery (requires Avahi reachability).
            '';
          };
          discovery = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Allow mDNS discovery in addition to any pinned device";
          };
        };
      };

      config = lib.mkIf (cfg.address != null) {
        # Patch upstream scanservjs to ship the built UI assets.
        #
        # nixpkgs uses buildNpmPackage's `npm pack` install path, which
        # respects scanservjs's .gitignore — and `dist/` (the very directory
        # `node build.js --assemble` produces, containing the built Vue UI
        # at `dist/client/`) is gitignored. The shipped wrapper launches
        # `app-server/src/server.js`, whose `express.static('client')` has
        # no `client/` to serve, so every non-API route returns 404.
        #
        # The upstream source server is otherwise functional (the API works);
        # we just need the static assets reachable from cwd. We copy
        # `dist/client/` into $out and (below, via systemd.tmpfiles) symlink
        # it into the runtime working dir so express.static('client') resolves.
        nixpkgs.overlays = [
          (_final: prev: {
            scanservjs = prev.scanservjs.overrideAttrs (_old: {
              postInstall = ''
                mkdir -p $out/bin
                makeWrapper ${lib.getExe prev.nodejs_20} $out/bin/scanservjs \
                  --set NODE_ENV production \
                  --add-flags "$out/lib/node_modules/scanservjs/app-server/src/server.js"

                if [ ! -d ./dist/client ]; then
                  echo "scanservjs override: ./dist/client missing — UI build did not produce expected files" >&2
                  exit 1
                fi
                cp -r ./dist/client "$out/lib/node_modules/scanservjs/client"

                # Vite build doesn't emit app-ui/src/icons/ into dist/client/.
                # The PWA manifest + index.html reference /icons/*.png at runtime,
                # so ship them alongside the built bundle.
                if [ -d ./app-ui/src/icons ]; then
                  cp -r ./app-ui/src/icons "$out/lib/node_modules/scanservjs/client/icons"
                fi

                # nixpkgs's NixOS module exports NIX_SCANSERVJS_CONFIG_PATH but
                # upstream user-options.js only loads config.local.js from a
                # hardcoded relative path. Without this patch the env var is
                # ignored and all module config (scanimage path, output dir,
                # host/port) silently falls back to defaults — most visibly
                # the bundled "/usr/bin/scanimage" which doesn't exist on NixOS.
                substituteInPlace $out/lib/node_modules/scanservjs/app-server/src/classes/user-options.js \
                  --replace-fail \
                    'const localPath = path.join(__dirname, localConfigPath);' \
                    'const localPath = process.env.NIX_SCANSERVJS_CONFIG_PATH || path.join(__dirname, localConfigPath);'
              '';
            });
          })
        ];

        services.scanservjs = {
          enable = true;
          settings = {
            host = cfg.address;
            port = cfg.port;
            outputDirectory = cfg.outputDir;
          };
        };

        # Make `client/` reachable from scanservjs's WorkingDirectory so the
        # express.static('client') middleware (relative path in upstream
        # source) finds the built UI assets we shipped in the package.
        # Also stage data/preview/default.jpg — scanservjs reads this stock
        # placeholder via Config.previewDirectory ('data/preview' relative to
        # cwd) when the UI mounts and there's no scan to show; without it
        # /api/v1/preview returns 500 and the UI tries to atob() the error.
        systemd.tmpfiles.settings."10-scanservjs-ui" = {
          "/var/lib/scanservjs/client"."L+" = {
            argument = "${pkgs.scanservjs}/lib/node_modules/scanservjs/client";
          };
          "/var/lib/scanservjs/data/preview"."d" = {
            user = "scanservjs";
            group = "scanservjs";
            mode = "0750";
          };
          "/var/lib/scanservjs/data/preview/default.jpg"."L+" = {
            argument = "${pkgs.scanservjs}/lib/node_modules/scanservjs/app-server/data/preview/default.jpg";
          };
        };

        hardware.sane = {
          enable = true;
          extraBackends =
            [ pkgs.sane-airscan ]
            ++ lib.optional (airscanOverlay != null) airscanOverlay;
        };

        systemd.tmpfiles.settings."10-scanservjs" = {
          ${cfg.outputDir}."d" = {
            user = "scanservjs";
            group = "scanservjs";
            mode = "0750";
          };
        };

        networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
      };
    };
}
