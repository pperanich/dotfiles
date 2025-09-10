{
  outputs,
  pkgs,
  ...
}: {
  imports =
    builtins.attrValues outputs.nixosModules
    ++ [
      ./hardware-configuration.nix
    ];

  nixpkgs.hostPlatform = "aarch64-linux";

  my = {
    core.enable = true;
    users.pperanich.enable = true;
    features.tailscale.enable = true;
    features.couchdb.enable = true;
  };

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
