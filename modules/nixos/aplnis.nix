{ config, lib, pkgs, ... }:
let
  curl-openssl-v1 = pkgs.curl.override { openssl = pkgs.openssl_1_1; };
  cert = builtins.fetchurl {
    url = "https://apllinuxdepot.jhuapl.edu/linux/APL-root-cert/JHUAPL-MS-Root-CA-05-21-2038-B64-text.cer";
    sha256 = "sha256:169zi75ca4w2175c68837khvbid8lvgap8y50scnbgivh2rxzaps";
  };

  bncsaui-autostart = pkgs.writeTextFile {
    name = "autostart-bncsaui";
    destination = "/etc/xdg/autostart/bncsaui.desktop";
    text = ''
      [Desktop Entry]
      Type=Application
      Exec=${pkgs.fortinac}/bin/bncsaui
      Name=FortiNAC Persistent Agent
      Categories=System
      '';
  };
  persistent-agent-conf = pkgs.writeTextFile {
    name = "persistent-agent-conf";
    destination = "/etc/xdg/com.bradfordnetworks/PersistentAgent.conf";
    text = ''
      [General]
      allowedCiphers="TLS_AES_256_GCM_SHA384,TLS_AES_128_GCM_SHA256,TLS_CHACHA20_POLY1305_SHA256,ECDHE-RSA-AES128-GCM-SHA256"
      caTrustDepth=4
      caFile=/etc/ssl/certs/ca-bundle.crt
      selfSignedAllowed=true
      discoveryEnabled=true
      restrictRoaming=false
      homeServer=
      allowedServers=
      maxConnectInterval=960
      macPollInterval=5
      showDisconnectedIcon=false
      showDisconnectedMsg=false
      disconnectedMsg="Your network access may be restricted.  Persistent Agent is disconnected from Network Sentry."
      ShowIcon=1
      '';
  };

  cfg = config.modules.aplnis;

in
{
  options.modules.aplnis = {
      enable = lib.mkEnableOption "Enables DFARS compliance";
  };

  config = lib.mkIf cfg.enable {

    xdg.autostart.enable = true;
    systemd.services.bndaemon = {
      description = "bndaemon";
      path = [ pkgs.fortinac ];
      serviceConfig.ExecStart = ''${pkgs.fortinac}/bin/bndaemon -d -p /var/run/bndaemon.pid -l /var/log/bndaemon'';
      serviceConfig.Restart = "on-failure";
    };

    # Time Synchronization
    services.ntp.enable = true;
    networking.timeServers = [ "apltime.jhuapl.edu" "apltime2.jhuapl.edu" ];

    # Resolve hosts on dom1.jhuapl.edu
    networking.search = [ "jhuapl.edu" "dom1.jhuapl.edu" ];

    # Must use openSSL v1 on APLNIS
    nixpkgs = {
      config = {
        permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
      };
    };
    programs.git.package = pkgs.git.override { openssl = pkgs.openssl_1_1; curl = curl-openssl-v1; };

    environment.systemPackages = [
      bncsaui-autostart
      persistent-agent-conf
      pkgs.fortinac
    ];

    ########################################
    # region: Certificate setup
    ########################################
    security.pki.certificateFiles = [ cert ];
    ########################################
    # endregion: Certificate setup
    ########################################

    ########################################
    # region: LDAP setup
    ########################################
    # NOTE: LDAP config
    # base
    # timelimit 120
    # bind_timelimit 120
    # idle_timelimit 3600
    # ssl no
    # pam_password md5
    # bind_policy     soft
    # pam_lookup_policy       yes
    # nss_initgroups_ignoreusers      root,ldap
    # nss_schema      rfc2307bis
    # nss_map_attribute       uniqueMember memb

    # NOTE: nsswitch.conf
    # passwd: files ldap [UNAVAIL=return] compat
    # group: compat
    # shadow: compat

    # See: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/config/nsswitch.nix
    #      https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/config/ldap.nix
    #      https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/system/nscd.nix
    users.ldap = {
      enable = true;
      loginPam = true;
      nsswitch = true;
      server = "ldap://oid.jhuapl.edu";
      base = "cn=users,dc=jhuapl,dc=edu";
      useTLS = false;
      timeLimit = 120;
      # daemon.enable = true;
      bind = {
        policy = "soft";
        timeLimit = 120;
      };
    };
    services.nscd = {
      enable = true;
    };
    ########################################
    # endregion: LDAP setup
    ########################################

    ########################################
    # region: krb5 setup
    ########################################

    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/security/krb5/default.nix

    # NOTE:
    # [logging]
    #  default = FILE:/var/log/krb5libs.log
    #  kdc = FILE:/var/log/krb5kdc.log
    #  admin_server = FILE:/var/log/kadmind.log
    # [libdefaults]
    #  default_realm = DOM1.JHUAPL.EDU
    #  dns_lookup_realm = false
    #  dns_lookup_kdc = false
    #  ticket_lifetime = 24h
    #  renew_lifetime = 7d
    #  forwardable = true
    #  verify_ap_req_nofail = false
    # [realms]
    #  DOM1.JHUAPL.EDU = {
    #   kdc = dom1.jhuapl.edu:88
    #  }
    # [domain_realm]
    #  .dom1.jhuapl.edu = DOM1.JHUAPL.EDU
    #  dom1.jhuapl.edu = DOM1.JHUAPL.EDU

    ########################################
    # endregion: krb5 setup
    ########################################

    ########################################
    # region: pam setup
    ########################################
    # security.pki.certificateFiles = [ ./JHUAPL-MS-Root-CA-05-21-2038-B64-text.crt ];
    ########################################
    # endregion: pam setup
    ########################################

    # NOTE: /etc/pam.d/common-auth
    # auth    required            pam_tally2.so onerror=fail deny=10 unlock_time=43200 audit even_deny_root root_unlock_time=86400
    # # here are the per-package modules (the "Primary" block)
    # auth    [success=3 default=ignore]  pam_krb5.so minimum_uid=1000
    # auth    [success=2 default=ignore]  pam_unix.so nullok_secure try_first_pass
    # auth    [success=1 default=ignore]  pam_ldap.so use_first_pass
    # # here's the fallback if no module succeeds
    # auth    requisite           pam_deny.so
    # # prime the stack with a positive return value if there isn't one already;
    # # this avoids us returning an error just because nothing sets a success code
    # # since the modules above will each just jump around
    # auth    required            pam_permit.so
    # # and here are more per-package modules (the "Additional" block)
    # auth    optional            pam_cap.so
    # # end of pam-auth-update config

    # NOTE: /etc/pam.d/common-account
    # # here are the per-package modules (the "Primary" block)
    # account [success=2 new_authtok_reqd=done default=ignore]    pam_unix.so
    # account [success=1 default=ignore]  pam_ldap.so
    # # here's the fallback if no module succeeds
    # account requisite           pam_deny.so
    # # prime the stack with a positive return value if there isn't one already;
    # # this avoids us returning an error just because nothing sets a success code
    # # since the modules above will each just jump around
    # account required            pam_permit.so
    # # and here are more per-package modules (the "Additional" block)
    # account required            pam_krb5.so minimum_uid=1000
    # # end of pam-auth-update config
    # account required            pam_tally2.so

    ########################################
    # endregion: Firefox setup
    ########################################

    programs.firefox = {
      # policies = {
      #   "Authentication" = {
      #     "SPNEGO" = ["mydomain.com", "https://myotherdomain.com"]
      #   }
      # }
      preferences = {
        "network.negotiate-auth.trusted-uris" = ".jhuapl.edu";
        "network.automatic-ntlm-auth.trusted-uris" = ".jhuapl.edu";
      };
    };
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/programs/firefox.nix

    ########################################
    # endregion: Firefox setup
    ########################################
  };
}
