# Secrets with sops-nix

Secrets live encrypted in `sops/secrets.yaml`, committed to git. Decryption keys are age keys, and every age key here is derived from an existing ed25519 SSH key, so there is no extra key material to manage.

## Three decryption identities

| Who       | Key                              | Used for                                   |
| --------- | -------------------------------- | ------------------------------------------ |
| You       | `~/.ssh/id_ed25519`              | editing secrets (`sops sops/secrets.yaml`) |
| Each host | `/etc/ssh/ssh_host_ed25519_key`  | system secrets at activation               |
| Each user | `~/.ssh/id_ed25519` on that host | home-manager secrets at activation         |

The user's private key is itself a secret: the system-level sops in `modules/users/example.nix` writes it to `~/.ssh/id_ed25519` using the **host** key, and home-manager's sops then uses it. That ordering is why a fresh machine works with nothing hand-copied.

## First-time setup

```bash
nix develop                      # exports SOPS_AGE_KEY from your SSH key

# 1. your admin recipient
ssh-to-age < ~/.ssh/id_ed25519.pub

# 2. each host's recipient (run on the host, or against its public key)
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# 3. paste both into sops/.sops.yaml, then create the real secrets file
rm sops/secrets.yaml
sops sops/secrets.yaml

# 4. modules/system/sops.nix: validateSopsFiles = true;
```

## Adding a secret

Add the key in the editor (`sops sops/secrets.yaml`), then declare where it should land.

System scope, `/run/secrets/<name>`:

```nix
sops.secrets."api_keys/cloudflare" = {
  owner = "caddy";
  mode = "0400";
};

services.caddy.environmentFile = config.sops.secrets."api_keys/cloudflare".path;
```

Home-manager scope, `~/.config/sops-nix/secrets/<name>` — declare it in `modules/system/sops.nix` under `homeManager.sops`:

```nix
secrets."api_keys/openai" = { };
```

Composing several secrets into one config file, without any of them hitting the Nix store:

```nix
sops.templates."service.env" = {
  content = ''
    TOKEN=${config.sops.placeholder."api_keys/cloudflare"}
  '';
  owner = "caddy";
};
```

## Adding a host

```bash
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub   # on the new host
# add as an anchor in sops/.sops.yaml, list it under creation_rules
sops updatekeys sops/secrets.yaml                # re-encrypt to the new recipient set
```

Forgetting `updatekeys` is the usual failure: the host boots but `sops-install-secrets` fails with "no key found".
