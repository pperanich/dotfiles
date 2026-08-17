# What this repo inherits, and what it owes

This flake has one input. Everything it builds with comes from there, which
buys atomic version bumps and costs you the ability to override anything.

## One input

`upstream.inputs` is merged into this flake's `inputs` under the bare names, so
`inputs.nixpkgs`, `inputs.clan-core` and `inputs.sops-nix` all resolve, and a
flake-parts module copied from the upstream repo works unchanged.

Two consequences:

- **`follows` is not available.** You cannot pin a different nixpkgs here. That
  is the point: the modules you import were evaluated against the upstream's
  nixpkgs, and a second one would let them disagree. nix-darwin asserts that
  its release matches nixpkgs, so a skew surfaces as a confusing eval error
  rather than a version warning.
- **`nix flake update` moves everything at once**, because there is one lock
  entry. Bumping nixpkgs is the upstream repo's decision, not this one's.

## `self` must be ours

`flake.nix` merges upstream's inputs but keeps this repo's own `self`:

```nix
inputs = upstream.inputs // { inherit self upstream; };
```

Clan derives its machine directory from `self`. Passing `self = upstream` makes
this flake enumerate the _upstream's_ `machines/`, and `nixosConfigurations`
comes back holding that repo's hosts alongside, or instead of, yours. It fails
silently, which is why the merge is written out in `flake.nix` rather than left
to the reader.

## Secrets: the keys a module drags in

Secrets are declared in _modules_, not machine files, so importing a module
imports its key requirements. The upstream's user module alone typically
demands `passwords/<user>` and `private_keys/<user>`.

Every one of those names must exist in this repo's `sops/secrets.yaml`. With
`sops.validateSopsFiles = true` upstream, a missing key fails the build rather
than the activation:

```
sops-install-secrets: manifest is not valid: secret private_keys/youruser in
/nix/store/…-secrets.yaml is not valid: the key 'private_keys' cannot be found
```

Treat the key names as part of each module's interface. Adding an upstream
module to a machine here means adding its keys to `sops/secrets.yaml` too.

Two settings in `machines/<host>/configuration.nix` make this work at all:

| setting                                          | why                                                                                              |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| `sops.defaultSopsFile = ../../sops/secrets.yaml` | the upstream's path resolves to _its_ secrets file, whose recipients do not include this machine |
| `sops.age.keyFile = "/var/lib/sops-nix/key.txt"` | clan vars provisions this; the upstream default reads the host SSH key                           |

## What does not cross the boundary

Clan service instances are per-inventory. A machine here cannot be a peer in
the upstream clan's wireguard instance, a borgbackup client of its server, a
syncthing peer, or a holder of its sshd CA certificates. Each clan has its own
inventory, its own vars store, and its own `clan machines list`.

That is fine for an isolated host and wrong for anything that needs the mesh.
If a private machine needs to join the upstream's services, the two repos have
to become one clan, which means one secrets store: either the public repo holds
the private machines' vars, or every machine's vars move here.
