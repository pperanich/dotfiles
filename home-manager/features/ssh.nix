{ inputs, outputs, lib, config, pkgs, ... }:
{
  home.packages = with pkgs; [
    xorg.xauth
  ];

  programs.ssh.enable = true;
  programs.ssh.extraConfig = ''
    Host lv1
      HostName peranpl1-lv1
      User peranpl1
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host lv2
      HostName peranpl1-lv2
      User peranpl1
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host hst-redd-holobrain
      HostName 10.124.29.199
      User hst
      ForwardX11 yes
      # XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host redd-holobrain
      HostName redd-holobrain
      User peranpl1
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host microtik
      HostName 10.101.14.123
      User admin

    Host asus
      # HostName 10.101.15.91
      HostName 10.101.16.41
      User admin

    Host holobrain-ld1
      HostName 10.101.61.57
      User peranpl1
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host holo-holobrain-ld1
      HostName 10.101.61.57
      User holo
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host holobrain-ld2
      HostName 10.124.29.188
      User peranpl1
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host holo-holobrain-ld2
      HostName 10.124.29.188
      User holo
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host holobrain-ld3
      HostName holobrain-ld3
      User peranpl1
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host holo-holobrain-ld3
      HostName holobrain-ld3.local
      User holo
      ForwardX11 yes
      XAuthLocation ${pkgs.xorg.xauth}/bin/xauth

    Host raspi1
      HostName 10.101.16.78
      User pi

    Host raspi3
      HostName 10.101.16.54
      User pi
    Host raspi1.axisrt.com
      HostName 192.168.88.105
      User pi

    Host raspi2.axisrt.com
      HostName 192.168.88.106
      User pi

    Host raspi3.axisrt.com
      HostName 192.168.88.112
      User pi

    Host om-columbia-st1-ws1
      HostName 192.168.88.90
      User ubuntu

    Host om-apl-st1-ws1
      HostName 10.101.16.104
      User omni

    Host om-apl-st1-ws2
      HostName 10.101.16.103
      User omni

    Host om-apl-st1-ws3
      HostName 10.101.16.62
      User omni

    Host om-apl-st2-agx1
      HostName 10.101.16.84
      # HostName 192.168.1.71
      User nvidia

    Host om-apl-st1-raspi1
      HostName 10.101.16.78
      User pi

    Host om-apl-st1-raspi2
      HostName 10.101.16.53
      User pi

    Host om-apl-st1-raspi3
      HostName 10.101.16.96
      User pi

    Host om-apl-st1-raspi4
      HostName 10.101.16.54
      User pi

    Host om-apl-st2-raspi1
      HostName 10.101.16.96
      User pi

    Host om-apl-st2-raspi2
      HostName 10.101.16.53
      User pi

    Host pperanich-wd1
      Hostname pperanich-wd1.local
      User prest

    Host pperanich-wsl1
      Hostname pperanich-wd1.local
      User pperanich
      Port 3000
  '';
}
