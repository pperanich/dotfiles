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
        # scanservjs 3.1.0 (nixos-26.05) ships the built Vue UI at
        # $out/lib/client (express-configurer.js patched via @client@) and the
        # module sets NIX_SCANSERVJS_CONFIG_PATH + a preview tmpfiles link
        # itself. The old override that patched the pre-3.1.0
        # $out/lib/node_modules/scanservjs layout is obsolete and broke the
        # build, so stock scanservjs is used directly now.
        services.scanservjs = {
          enable = true;
          settings = {
            host = cfg.address;
            port = cfg.port;
            outputDirectory = cfg.outputDir;
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
