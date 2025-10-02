# Simple hotkey daemon
_: {
  flake.modules.darwin.skhd =
    { pkgs, ... }:
    {
      services.skhd = {
        enable = true;
        package = pkgs.skhd;
      };

      environment.systemPackages = [ pkgs.skhd ];

      # For skhd debugging
      launchd.user.agents.skhd.serviceConfig.StandardErrorPath = "/tmp/skhd.err.log";
      launchd.user.agents.skhd.serviceConfig.StandardOutPath = "/tmp/skhd.out.log";
    };
}
