_: {
  flake.modules.nixos.routerUnifi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.features.router;
      unifiCfg = cfg.unifi;
      internal = cfg._internal;
      inherit (internal) lanDevice;
      enabled = cfg.enable && unifiCfg.enable;

      # All LAN interfaces that need access to the controller
      # Main bridge + any VLAN bridges where APs might be
      controllerInterfaces = [
        lanDevice
      ]
      ++ lib.optionals cfg.networks.enable (
        lib.mapAttrsToList (name: _: "br-${name}") (
          lib.filterAttrs (_: seg: seg.vlan != null) cfg.networks.segments
        )
      );
    in
    {
      options.features.router.unifi = {
        enable = lib.mkEnableOption "Unifi controller for managing Ubiquiti access points";

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Open firewall ports for Unifi controller on LAN interfaces.
            This opens ports for device adoption (8080), discovery (10001),
            STUN (3478), and web UI (8443).
          '';
        };

        initialJavaHeapSize = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          example = 1024;
          description = ''
            Initial Java heap size in MB. If null, JVM auto-detects.
            Recommended: 1024 for small deployments, 2048 for 100+ devices.
          '';
        };

        maximumJavaHeapSize = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          example = 2048;
          description = ''
            Maximum Java heap size in MB. If null, JVM auto-detects.
            Recommended: 2048 for small deployments, 4096 for 100+ devices.
          '';
        };

        extraJvmOptions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "-Xlog:gc" ];
          description = "Extra JVM options for the Unifi controller";
        };
      };

      config = lib.mkIf enabled {
        # Unifi controller service
        services.unifi = {
          enable = true;
          # Don't use the built-in openFirewall - we handle it ourselves
          # to integrate with the router's nftables setup
          openFirewall = false;
          inherit (unifiCfg) initialJavaHeapSize maximumJavaHeapSize extraJvmOptions;
        };

        # Export firewall rules for injection into firewall.nix
        features.router._internal.unifiFirewall = lib.mkIf unifiCfg.openFirewall {
          inputRules = lib.concatMapStringsSep "\n" (iface: ''
            # Unifi controller - ${iface}
            iifname "${iface}" tcp dport 8080 accept comment "Unifi inform (${iface})"
            iifname "${iface}" tcp dport 8443 accept comment "Unifi web UI (${iface})"
            iifname "${iface}" udp dport 3478 accept comment "Unifi STUN (${iface})"
            iifname "${iface}" udp dport 10001 accept comment "Unifi discovery (${iface})"
            iifname "${iface}" tcp dport 6789 accept comment "Unifi speedtest (${iface})"
          '') controllerInterfaces;
        };

        # Unifi tools
        environment.systemPackages = [ pkgs.unifi ];
      };
    };
}
