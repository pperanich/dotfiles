# Persistent externally-gated services: one entry per app drives the Caddy
# localhost listener, the tunnel ingress, and the Cloudflare Access allowlist
# together, so a service is never exposed without its login gate.
#
# The allowlist emails are NOT stored here. Each managed entry names a sops
# secret (`emailsSecret`) that holds a JSON array of addresses, e.g.
#   gitea-allowlist: '["alice@example.com","bob@example.com"]'
# The secret is spliced into a sops-rendered config at runtime, so the emails
# never enter git or the world-readable nix store. Add/change emails with
# `sops <secrets file>` then `systemctl start cf-access-sync` (or wait for the
# timer) to apply.
#
# Entry fields:
#   sub             subdomain label (joined with the public domain)
#   backend         reverse_proxy target, e.g. "localhost:3000"
#   port            unique loopback port for the tunnel listener (8225+)
#   emailsSecret    sops secret holding a JSON array of allowed emails
#   sessionDuration optional, default "24h"
#   extraConfig     optional extra Caddy directives inside reverse_proxy
{
  config,
  lib,
  ...
}:
let
  inherit (lib.my.homelab) mkSub;

  tunnelApps = [
    {
      sub = "git";
      backend = "localhost:${toString config.my.gitea.port}";
      port = 8225;
      emailsSecret = "gitea-allowlist";
      extraConfig = "header_up X-Forwarded-Proto {scheme}";
    }
  ];

  # Apps whose Access gate is managed declaratively (vs. an external portal app).
  managed = builtins.filter (a: a ? emailsSecret) tunnelApps;

  mkListener =
    app:
    lib.nameValuePair "http://:${toString app.port}" {
      listenAddresses = [ "127.0.0.1" ];
      extraConfig = ''
        reverse_proxy ${app.backend} {
          ${app.extraConfig or ""}
        }
      '';
    };

  mkIngress = app: lib.nameValuePair (mkSub app.sub) "http://localhost:${toString app.port}";

  # One JSON object per managed app. The emails value is the sops placeholder,
  # replaced with the secret's JSON array when the template is rendered.
  mkAppJson =
    app:
    ''{"domain":"${mkSub app.sub}","name":"cf-access: ${app.sub}",''
    + ''"sessionDuration":"${app.sessionDuration or "24h"}",''
    + ''"emails":${config.sops.placeholder.${app.emailsSecret}}}'';

  accessConfig = ''{"apps":[${lib.concatMapStringsSep "," mkAppJson managed}]}'';
in
{
  services.caddy.virtualHosts = lib.listToAttrs (map mkListener tunnelApps);

  my.cloudflareTunnel.ingress = lib.listToAttrs (map mkIngress tunnelApps);

  sops.secrets = lib.genAttrs (map (a: a.emailsSecret) managed) (_: { });

  sops.templates."cf-access-apps.json" = lib.mkIf (managed != [ ]) {
    content = accessConfig;
  };

  my.cloudflareAccess = lib.mkIf (managed != [ ]) {
    enable = true;
    configFile = config.sops.templates."cf-access-apps.json".path;
    environmentFile = config.sops.templates."cf-dns.env".path;
  };

  # Publish the tunnel CNAMEs only after the Access gate has been reconciled, so
  # a gated host isn't routable before its login gate exists. Best-effort
  # ordering (`wants`, not `requires`): a gitea allowlist failure must not also
  # block DNS for ungated services on the same tunnel. The gate persists at
  # Cloudflare once created, so the exposed-before-gated window is first-deploy
  # only, and cf-access-sync fails loudly if it can't establish it.
  systemd.services.cf-tunnel-dns-sync = lib.mkIf (managed != [ ]) {
    after = [ "cf-access-sync.service" ];
    wants = [ "cf-access-sync.service" ];
  };
}
