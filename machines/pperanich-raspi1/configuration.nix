{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix

    # Core system configuration (minimal for Pi)
    inputs.self.modules.nixos.base

    # User setup
    inputs.self.modules.nixos.pperanich

    # Basic utilities
    inputs.self.modules.nixos.fileExploration
    inputs.self.modules.nixos.networkUtilities

    # Database services
    inputs.self.modules.nixos.couchdb
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  environment.systemPackages = with pkgs; [
    libraspberrypi
  ];

  networking = {
    hostName = "pperanich-raspi1";
    useDHCP = true;
    wireless = {
      enable = true;
      networks."VirusInfectedWifi".psk = "vacinate";
      interfaces = ["wlan0"];
    };
    interfaces.eth0 = {
      useDHCP = true;
      wakeOnLan.enable = true;
    };
  };

  systemd.services.btattach = {
    before = ["bluetooth.service"];
    after = ["dev-ttyAMA0.device"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.bluez}/bin/btattach -B /dev/ttyAMA0 -P bcm -S 3000000";
    };
  };
}
