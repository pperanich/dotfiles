{ inputs, lib, pkgs, config, modulesPath, ... }:
{
  imports = [
    inputs.NixOS-WSL.nixosModules.wsl
    # "${modulesPath}/profiles/minimal.nix"
  ];

  wsl = {
    enable = true;
    startMenuLaunchers = true;
    nativeSystemd = true;
    defaultUser = "pperanich";
    interop.register = true;

    wslConf = {
      automount.root = "/mnt";
    };

    # Enable native Docker support
    # docker-native.enable = true;

    # Enable integration with Docker Desktop (needs to be installed)
    docker-desktop.enable = true;
    # virtualisation.docker.enable = true;

  };

  # Enable cron service
  services.cron = {
    enable = true;
    systemCronJobs = [
      "@reboot root echo 'startup called from crontab!' >> /tmp/test.txt && nohup bash -c 'while true; do sleep 1h; done &' && dbus-launch true"
    ];
  };
}
