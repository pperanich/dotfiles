# Secrets and Key Management

How secrets are encrypted, who can decrypt them, and how to edit, add and rotate them. Secrets use sops-nix with age keys. There is no other secret system in this repo.

## Layout

| File                                | Holds                                                          | Decrypted by             |
| ----------------------------------- | -------------------------------------------------------------- | ------------------------ |
| `sops/machines/<host>.yaml`         | That host's service secrets and its `passwords/pperanich` hash | The host, at activation  |
| `sops/users/pperanich-desktop.yaml` | API keys that home-manager installs on the admin workstation   | Home-manager on `pp-ml1` |
| `sops/cloudflared-tunnel.json`      | The Cloudflare Tunnel credential                               | `pp-router1`             |
| `sops/.sops.yaml`                   | Recipients and creation rules for all of the above             | (not encrypted)          |

There is one file per host and no shared file. A host's file is not readable by any other host. The old monolithic `sops/secrets.yaml` no longer exists.

## Keys

| Key                 | Where the private half lives                                      | Recipient of                                            | Purpose                                               |
| ------------------- | ----------------------------------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------- |
| Admin age key       | `~/.config/sops/age/keys.txt` on `pp-ml1`, plus an offline backup | Every file                                              | Editing secrets, re-encrypting files                  |
| YubiKeys            | Two tokens (`&yubikey0-slot1`, `&yubikey1-slot1` in `.sops.yaml`) | Every file                                              | Fallback for editing if the admin key file is missing |
| Host key (per host) | `/etc/ssh/ssh_host_ed25519_key` on that host                      | That host's file (and the tunnel file for `pp-router1`) | System decryption at activation                       |

The host recipient is the SSH host key converted to age with `ssh-to-age`; it is not a separate key to manage. `.sops.yaml` lists a recipient for each of `pp-ml1` (as `&pp-ml1-ssh`), `pp-nas1`, `pp-router1` and `pp-wsl1`. `pp-rpi1` is powered off until re-imaged, so its file is encrypted to the admin key and the YubiKeys only; a host recipient goes in when the machine gets a new key (see [Adding New Machines](adding-new-machines.md)).

A secret is readable by any one recipient of its file. The admin key and either YubiKey can therefore read everything; a host can read only its own file.

## How decryption works

Hosts decrypt with their SSH host key and nothing else (`modules/system/sops.nix` sets `sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]` and `sops.age.keyFile = null`). Each host's `sops.defaultSopsFile` is `sops/machines/<networking.hostName>.yaml`.

Home-manager decrypts with `~/.config/sops/age/keys.txt` and reads `sops/users/pperanich-desktop.yaml`. A missing key file fails the install, so a workstation needs the file in place before its first switch. Home-manager runs as the user and cannot read the host key, which is why it has a key of its own. On `pp-ml1` the file holds the admin key.

`sops.validateSopsFiles = true`, so a secret that a module declares but the host's file lacks fails the build, not the activation. Key names are plaintext in a sops file, so this check decrypts nothing.

The Mac needs two extras (both in `modules/system/sops.nix`): the system module forces a minimal `PATH` so `hdiutil` is found, and the home-manager launch agent adds `age-plugin-yubikey` to its `PATH`.

## Editing secrets

From the repo root, inside `nix develop` (which exports `SOPS_CONFIG` through `.envrc` and `SOPS_AGE_KEY_FILE` through the dev shell):

```bash
sops --config sops/.sops.yaml sops/machines/pp-nas1.yaml
```

This opens the decrypted file in `$EDITOR` and re-encrypts on save. To set one value without writing it to disk or the shell history:

```bash
printf '%s' "$VALUE" | jq -Rs . | sops --config sops/.sops.yaml set --value-stdin sops/machines/pp-nas1.yaml '["some-key"]'
```

A nested name such as `passwords/pperanich` is a nested mapping, so its index is `'["passwords"]["pperanich"]'`.

## Adding a secret

1. Declare it in the module that uses it (`sops.secrets.<name>`; see [Secrets in Modules](../AGENTS.md#secrets-in-modules) for the pattern, including templates and the missing-secret assertion).
2. Add the value under the same name to the `sops/machines/<host>.yaml` of every host that enables that module.
3. Build. A host whose file lacks the key fails with `the key '<name>' cannot be found`.

Secrets for home-manager go in `sops/users/pperanich-desktop.yaml` and are declared in `modules/shell/api-keys.nix`. That file is encrypted to the admin key, the YubiKey and `pp-ml1` only; keep servers and WSL out of its rule.

## Rotating a secret

1. Change the value in the file (`sops set` or the editor).
2. Deploy the host (`deploy .#<host>`, or `nh darwin switch . -H pp-ml1`).
3. Restart whatever read the old value, if the module does not do it for you.

Two things decide whether a rotation takes effect:

- A service that reads a secret only at startup needs `restartUnits` on that secret (or its template), or the old value stays in memory until the next reboot. Existing examples are in `modules/services/headplane.nix` and `modules/services/radicale.nix`.
- An application that reads an admin password only at first setup (a database seeded on first run, for instance) ignores later changes to the file. Change the password inside the application as well.

To replace the data key of a file without changing recipients, run `sops --config sops/.sops.yaml rotate -i <file>`. `updatekeys` changes recipients but keeps the same data key, so it is not a substitute.

## Changing recipients

After editing recipients or rules in `sops/.sops.yaml`, re-encrypt each file that the rule covers:

```bash
sops --config sops/.sops.yaml updatekeys sops/machines/<host>.yaml
```

`updatekeys` asks for confirmation and needs a current recipient's private key (the admin key or the YubiKey). Then check the result:

```bash
grep -n "recipient:" sops/machines/<host>.yaml
```

### Replacing a host key

1. Create the new key on the host (or at install time, as in [Adding New Machines](adding-new-machines.md)).
2. Put its new age recipient in `.sops.yaml` and its public key in `lib/ssh-host-keys.nix`.
3. Run `updatekeys` on the host's file (and on `sops/cloudflared-tunnel.json` for `pp-router1`).
4. Deploy. Do not replace the key on the host before step 3, or its next activation cannot decrypt.

### Replacing the admin key

1. Generate the new key into a separate file, never over the current one: `age-keygen -o ~/.config/sops/age/keys-new.txt`.
2. Replace the `&pperanich-admin` recipient in `.sops.yaml` with the new public key.
3. Run `updatekeys` on every file in `sops/`, using the old key or the YubiKey.
4. Move the new file into place as `keys.txt`, back it up offline, and rotate each file's data key with `sops rotate -i`.

## If the admin key is lost

Each YubiKey is a recipient of every file, so either one can still read and re-encrypt everything.

1. Plug the YubiKey in. `age-plugin-yubikey` must be on `PATH` (the dev shell has it). Print its identity into a file that sops can read: `age-plugin-yubikey --identity > ~/.config/sops/age/yubikey-identity.txt`, then `export SOPS_AGE_KEY_FILE=~/.config/sops/age/yubikey-identity.txt`.
2. Generate a new admin key and follow "Replacing the admin key" above, from step 1.
3. Back the new key up offline.

If both the admin key and the YubiKey are gone, only each host's own key can still decrypt its file. Reading a file back off a host requires root on that host. Re-create anything else from the services that issued it.

## Traps

- Outside `nix develop`, plain `sops` cannot find `sops/.sops.yaml`. The `SOPS_CONFIG` export from `.envrc` hides this inside the repo. Always pass `--config sops/.sops.yaml` in scripts, tmux panes and one-off shells.
- Encrypting to the YubiKey recipient needs `age-plugin-yubikey` on `PATH`. In a bare shell, add it: `nix shell nixpkgs#sops nixpkgs#age-plugin-yubikey -c sops ...`.
- treefmt rewrites encrypted files and breaks every later edit. `modules/flake-parts/fmt.nix` excludes `sops/cloudflared-tunnel.json`, `sops/machines/*.yaml` and `sops/users/*.yaml`; keep new sops files under those globs.
- A new `creation_rules` entry only applies to files created after it. For an existing file, run `updatekeys`.

## References

- [sops-nix](https://github.com/Mic92/sops-nix)
- [age](https://github.com/FiloSottile/age)
- [ssh-to-age](https://github.com/Mic92/ssh-to-age)
- [age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey)
