_: {
  flake.modules.nixos.routerSqm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.router;
      sqmCfg = cfg.sqm;
      wan = cfg.wan.interface;
      enabled = cfg.enable && sqmCfg.enable;

      # Convert Mbps to kbit for tc
      downloadKbit = sqmCfg.downloadMbps * 1000;
      uploadKbit = sqmCfg.uploadMbps * 1000;
    in
    {
      options.my.router.sqm = {
        enable = lib.mkEnableOption "Smart Queue Management (SQM) for bufferbloat reduction";

        downloadMbps = lib.mkOption {
          type = lib.types.ints.positive;
          default = 900;
          description = ''
            Download speed in Mbps. Set slightly below actual speed (90-95%).
            This prevents the ISP's queue from filling up.
          '';
        };

        uploadMbps = lib.mkOption {
          type = lib.types.ints.positive;
          default = 40;
          description = ''
            Upload speed in Mbps. Set slightly below actual speed (90-95%).
            This is usually the more important setting for bufferbloat.
          '';
        };

        overhead = lib.mkOption {
          type = lib.types.int;
          default = 0;
          example = 44;
          description = ''
            Link layer overhead in bytes. Common values:
            - 0: Ethernet (default)
            - 8: PPPoE
            - 44: ATM/ADSL
          '';
        };
      };

      config = lib.mkIf enabled {
        # Ensure iproute2 is available for tc
        environment.systemPackages = [ pkgs.iproute2 ];

        # SQM setup service using CAKE qdisc
        systemd.services.sqm =
          let
            wanDevice = "sys-subsystem-net-devices-${wan}.device";
            overheadArg = lib.optionalString (sqmCfg.overhead > 0) "overhead ${toString sqmCfg.overhead}";
          in
          {
            description = "Smart Queue Management (SQM) with CAKE";
            after = [
              "network-online.target"
              wanDevice
            ];
            wants = [ "network-online.target" ];
            bindsTo = [ wanDevice ]; # Restart if WAN interface goes down
            wantedBy = [ "multi-user.target" ];

            path = [ pkgs.iproute2 ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              Restart = "on-failure";
              RestartSec = "5s";
              ExecStart = pkgs.writeShellScript "sqm-start" ''
                set -euo pipefail

                # Remove existing qdisc if present
                tc qdisc del dev ${wan} root 2>/dev/null || true
                tc qdisc del dev ${wan} ingress 2>/dev/null || true

                # Egress (upload) shaping with CAKE
                # nat: accounts for NAT when tracking flows (required for router)
                # ack-filter: drops redundant ACKs to improve download on asymmetric links
                tc qdisc add dev ${wan} root cake bandwidth ${toString uploadKbit}kbit \
                  ${overheadArg} diffserv4 triple-isolate nat nowash ack-filter split-gso rtt 100ms

                # For ingress, we use an IFB (Intermediate Functional Block) device
                ip link add name ifb-wan type ifb 2>/dev/null || true
                ip link set ifb-wan up

                tc qdisc del dev ifb-wan root 2>/dev/null || true
                tc qdisc add dev ifb-wan root cake bandwidth ${toString downloadKbit}kbit \
                  ${overheadArg} diffserv4 triple-isolate nat ingress nowash no-ack-filter split-gso rtt 100ms

                # Redirect ingress traffic to IFB
                tc qdisc add dev ${wan} handle ffff: ingress
                tc filter add dev ${wan} parent ffff: protocol all u32 match u32 0 0 \
                  action mirred egress redirect dev ifb-wan

                echo "SQM (CAKE) configured: upload=${toString uploadKbit}kbit download=${toString downloadKbit}kbit"
              '';

              ExecStop = pkgs.writeShellScript "sqm-stop" ''
                tc qdisc del dev ${wan} root 2>/dev/null || true
                tc qdisc del dev ${wan} ingress 2>/dev/null || true
                ip link del ifb-wan 2>/dev/null || true
                echo "SQM stopped"
              '';
            };
          };

        # Ensure CAKE and IFB kernel modules are available
        boot.kernelModules = [
          "sch_cake"
          "ifb"
        ];
      };
    };
}
