# Host configuration for pp-rpi1 (Raspberry Pi 3B+ GPIO debugger host)
{
  config,
  inputs,
  lib,
  modules,
  pkgs,
  ...
}:
let
  openocdScriptDir = "${pkgs.openocd}/share/openocd/scripts";
  mkOpenOcdService =
    {
      name,
      interfaceConfig,
    }:
    {
      description = "OpenOCD ${name} session for target %I";
      documentation = [ "man:openocd(1)" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.openocd}/bin/openocd -f ${interfaceConfig} -f ${openocdScriptDir}/target/%I.cfg";
        Restart = "on-failure";
        RestartSec = "2s";
      };
      unitConfig.ConditionPathExists = "${openocdScriptDir}/target/%I.cfg";
    };
in
{
  imports = [
    ./hardware-configuration.nix
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    # Raspberry Pi 3 hardware support from nixos-hardware
    inputs.hardware.nixosModules.raspberry-pi-3
  ]
  ++ (with modules.nixos; [
    # Core system configuration
    base
    sops

    # User setup (headless — no desktop apps/fonts)
    pperanich
  ]);

  my.pperanich.desktop = false;

  nixpkgs.hostPlatform = "aarch64-linux";
  clan.core.networking.targetHost = lib.mkForce "root@pp-rpi1.pp-wg";
  clan.core.networking.buildHost = "root@pp-wsl1.pp-wg";

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = false;
  };

  users.users.pperanich.extraGroups = lib.mkAfter [
    "gpio"
    "dialout"
  ];

  users.groups.gpio = { };

  environment.systemPackages = with pkgs; [
    libraspberrypi
    gdb
    lldb
    openocd
    probe-rs-tools
    usbutils
  ];

  environment.etc = {
    "openocd/interface/raspberrypi-swd.cfg".source = ./openocd/interface/raspberrypi-swd.cfg;
    "openocd/interface/raspberrypi-jtag.cfg".source = ./openocd/interface/raspberrypi-jtag.cfg;
  };

  systemd.services = {
    "openocd-gpio-swd@" = mkOpenOcdService {
      name = "GPIO SWD";
      interfaceConfig = "/etc/openocd/interface/raspberrypi-swd.cfg";
    };
    "openocd-gpio-jtag@" = mkOpenOcdService {
      name = "GPIO JTAG";
      interfaceConfig = "/etc/openocd/interface/raspberrypi-jtag.cfg";
    };
  };

  # Networking configuration
  networking.hostName = "pp-rpi1";
  sops.templates."wireless.conf" = {
    content = "psk_passphrase=${config.sops.placeholder.wifi_passphrase}";
    # wpa_supplicant runs as the wpa_supplicant user in a sandboxed service,
    # so the secrets file must be readable by that user.
    owner = "wpa_supplicant";
    group = "wpa_supplicant";
    mode = "0400";
  };
  networking.wireless = {
    enable = true;
    secretsFile = config.sops.templates."wireless.conf".path;
    networks."PS-Net" = {
      pskRaw = "ext:psk_passphrase";
    };
  };
}
