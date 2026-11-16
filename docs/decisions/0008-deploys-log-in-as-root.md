# 0008: Deploys log in as root with the admin key

## Status

Accepted 2026-11-16.

## Context

deploy-rs logged in as `pperanich` and asked for the sudo password on every deploy, with root SSH off. deploy-rs itself warns that a sudo password is weaker than SSH keys, and on these hosts the password was not a real barrier: `pperanich` is a trusted Nix user, which is root-equivalent ([0007](0007-accepted-root-equivalents.md)).

Two other ways to drop the prompt were turned down. Passwordless sudo for `pperanich` gives root to anything running as that account, including day-to-day work on `pp-wsl1` and sessions opened through the Rex login server. A sudo rule limited to deploy-rs's activation command limits nothing, because the command lives at a store path any user can create.

## Decision

- deploy-rs uses `sshUser = "root"`. No sudo is involved.
- sshd on every NixOS host sets `PermitRootLogin = "prohibit-password"`. Root's `authorized_keys` is `lib.my.deploySshKeys`, which holds the key of `pp-ml1` and nothing else. A key added to `sshKeys` for login does not get root.
- `pperanich` keeps its sudo password on `pp-nas1` and `pp-router1`. `pp-wsl1` never asked for one: NixOS-WSL turns `wheelNeedsPassword` off.

## Consequences

- Whoever can use `pp-ml1`'s SSH private key is root on every host without a prompt. That includes any program running as `pperanich` on `pp-ml1`.
- sshd now answers root logins by key. Where it can be reached is unchanged: the router accepts port 22 from the main LAN and the tailnet, not from the WAN.
- A host still on the old configuration needs one last deploy the old way: `deploy --ssh-user pperanich --interactive-sudo true --hostname <host>.pp-ts .#<host>`.
- Deploys no longer need `pperanich` to be a trusted Nix user on the hosts. Setting `my.pperanich.trustedNixUser = false` there would close the path 0007 accepted; it is not done here.
