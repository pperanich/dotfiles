# 0002: Kanidm on pp-router1 is the identity provider for the homelab

## Status

Withdrawn 2026-11-14, after wave 1 (the server with only the admin) was built, deployed and then removed. Most of the planned integrations served apps only the owner uses, where a password manager already does the job, and the household's needs did not yet justify waves 3 to 5. The record below is kept for a later attempt; the wave 1 code is in commit `64c1fc1`.

Still open without it: Homepage and ntopng have no login of their own, scanservjs and Radicale share one `basic_auth` hash, and the Vaultwarden admin page has only its token. These are listed in `docs/todo.md`.

## Context

Every service on `pp-router1` and `pp-nas1` keeps its own accounts. Homepage and ntopng have no login of their own, and scanservjs and Radicale sit behind a single Caddy `basic_auth` hash. The household is starting to use the shared apps, and guests reach them over the tailnet, so adding or removing a person means editing each app by hand.

The repo's rule is that configuration lives in Nix and secrets in per-host sops files. The identity provider has to fit that rule.

## Decision

Run Kanidm on `pp-router1` as the single source of identities, reachable on the LAN and the tailnet only.

Server:

- Package `kanidmWithSecretProvisioning_1_11` (the NixOS module requires the patched build for `basicSecretFile` and the `idm_admin` password file). Only `idm_admin` has a stored password; `admin` is reached through `kanidmd recover-account` over SSH, since nothing in the rollout needs it. Upgrade one minor version at a time, as Kanidm requires.
- `origin` and `domain` are both `idm.prestonperanich.com`. Passkeys are bound to this name, so it does not change later.
- HTTPS on `127.0.0.1:8444` behind a Caddy vhost (UniFi already holds 8443). LDAPS on `10.0.0.1:636`, which nftables opens to `pp-nas1` only. Kanidm trusts the forwarded client address from loopback only.
- One `security.acme` DNS-01 certificate for `idm.prestonperanich.com`, used by Caddy (`useACMEHost`) and by Kanidm for HTTPS and LDAPS, so LDAP clients on the NAS verify an ordinary public certificate. lego reads `CLOUDFLARE_DNS_API_TOKEN`, so the module renders its own env file from the shared Cloudflare token.
- `online_backup` dumps go into the router's Borg job; the Kanidm module registers the path itself. Blackbox probes `/status`, and `kanidm` joins the log-shipping unit list.
- Lost-access recovery is `kanidmd recover-account` over SSH. SSH and sudo never depend on Kanidm.

Identities, all declared through `services.kanidm.provision`:

- Groups `homelab_admins`, `homelab_members` and `homelab_guests`. Each OIDC client's scope maps decide which groups may sign in; claim maps carry app roles (Grafana role, Gitea admin, `immich_role`).
- `preferShortUsername = true`, so apps see `pperanich` rather than `pperanich@idm.prestonperanich.com`.
- `autoRemove = true`: removing a person or client from Nix deletes it in Kanidm.
- Every group's minimum credential is a passkey. Account policy, LDAP applications and credential reset links are not covered by provisioning and are run once from the CLI, recorded in the runbook.

Client registration:

- Each service module declares its OIDC client under `my.oidc.clients.<id>` on its own host. `machines/pp-router1` merges its own clients with `pp-nas1`'s (read from `self.nixosConfigurations.pp-nas1.config`) into Kanidm's provisioning. The idm domain is a constant in `lib.my.homelab`, so no host reads the router's configuration.
- Clients are confidential. The secret is the sops key `oidc-<id>`. For NAS services it is stored in both `sops/machines/pp-router1.yaml` and `sops/machines/pp-nas1.yaml`, generated once and written to both with `sops set`.

Forward auth for apps that cannot speak OIDC: one oauth2-proxy per host (router and NAS), each its own Kanidm client, with host-only cookies. A vhost restricts groups through `allowed_groups` on the auth request. The NAS runs its own instance because LAN clients reach the NAS's Caddy directly through split-horizon DNS and never pass the router. Caddy strips client-sent `X-Auth-Request-*` headers before forward auth.

Per service:

| Service              | Host   | Method                                                                  | Allowed groups  |
| :------------------- | :----- | :---------------------------------------------------------------------- | :-------------- |
| Grafana              | router | OIDC                                                                    | admins          |
| Headplane            | router | OIDC (still needs a Headscale API key)                                  | admins          |
| Gitea                | router | OIDC, configured by an idempotent `gitea admin auth` service            | admins          |
| Homepage             | router | forward auth                                                            | all             |
| ntopng               | router | forward auth plus its own login                                         | admins          |
| Vaultwarden `/admin` | router | forward auth in front of the admin token                                | admins          |
| Immich               | NAS    | OIDC, web and mobile                                                    | members, guests |
| Nextcloud            | NAS    | OIDC through `user_oidc`                                                | members         |
| OpenCloud            | NAS    | OIDC, after a compatibility check                                       | members         |
| Paperless            | NAS    | OIDC through allauth                                                    | members         |
| Audiobookshelf       | NAS    | OIDC, set in its admin UI                                               | members, guests |
| scanservjs           | NAS    | forward auth (replaces its `basic_auth` hash)                           | members         |
| Navidrome            | NAS    | header auth behind forward auth for the web UI; `/rest/*` bypasses it   | members, guests |
| Jellyfin             | NAS    | LDAP plugin with Kanidm application passwords                           | members, guests |
| Radicale             | NAS    | LDAP with Kanidm application passwords (replaces its `basic_auth` hash) | members         |

Admins belong to every group in this table. Each app keeps one local admin account as a break-glass login, and its password login stays enabled until the linked account is verified. Git over SSH is unchanged; Git over HTTPS uses a token or `git-credential-oauth`, never forward auth.

Rollout order: Kanidm itself with only the admin provisioned; router apps and the router's oauth2-proxy; NAS web apps and the NAS's oauth2-proxy; LDAPS with Jellyfin and Radicale; then household accounts. Before an app with existing accounts switches over, take a ZFS snapshot and rehearse the account link with a throwaway Kanidm person. Immich holds household data; the other apps hold only the admin's own account.

## Alternatives considered

- Authelia with its file backend: more declarative (users and password hashes live in sops) and has forward auth built in, but serves no LDAP for TV and CalDAV clients, and stores password hashes where Kanidm stores none.
- Pocket ID and Rauthy: OIDC clients are created in a web UI or API, not in Nix. Rauthy also has no NixOS module and is pre-1.0 with one main maintainer.
- Authentik: not in nixpkgs and configured mostly in its UI.
- Keycloak and Zitadel: too heavy for two hosts; the packaged Zitadel is two major versions behind upstream.
- Dex: declarative but has no MFA.
- Gitea as the identity provider: no new service, but Gitea generates client secrets, so they cannot be declared.
- Tailnet identity (`tsidp`, `caddy-tailscale`): Headscale issues no HTTPS certificates, every device here is tagged so its identity is a tag rather than a person, and LAN requests carry no tailnet identity.

## Consequences

Costs:

- One more service that every login depends on. If Kanidm is down, new logins fail everywhere; existing app sessions continue and local admins still work.
- A manual Kanidm package bump for each minor release.
- NAS client secrets live in two sops files, and a rotation must update both.
- Some setup cannot be declared: Gitea's login source needs a service that calls its CLI, Audiobookshelf and the Jellyfin LDAP plugin are configured in their UIs, and Kanidm account policy and application passwords are set from the CLI.

Gains:

- One passkey login for the web apps and one place to add or remove a person.
- Per-person, revocable application passwords for native clients (Jellyfin TV apps, CalDAV) instead of shared hashes.
- Homepage, ntopng, scanservjs and the Vaultwarden admin page gain a login they lack today.

Deferred:

- Headscale OIDC. Devices keep enrolling with pre-auth keys or `headscale nodes register`. Enabling it later means setting `oidc.only_start_if_oidc_is_available = false` (or ordering Headscale after Kanidm) and handling the default 180-day expiry on OIDC-enrolled devices.
- Home Assistant (its mobile app needs local logins), Docuseal (SSO is a paid feature), UniFi.
- Per-user Homepage views (two instances chosen by Caddy from the groups header).
- Public exposure of any service, and SSH or sudo through Kanidm.

Verified in the 1.11.2 source: the account policy's credential minimum applies only when a person sets their primary credential (`credupdatesession.rs`). An application-password LDAP bind checks the account's validity window, membership of the application's linked group, and the password (`idm/application.rs`), so a passkey-only policy leaves application passwords working.

To verify during rollout:

- OpenCloud's desktop and mobile apps use fixed client IDs, while Kanidm gives each client its own issuer. If they cannot work together, OpenCloud's built-in login authenticates against Kanidm's LDAP instead.
- Which clients need PKCE disabled or legacy (RS256) signing enabled.
- Nextcloud's `user_oidc` user-ID mapping must resolve to the existing `pperanich` account.
