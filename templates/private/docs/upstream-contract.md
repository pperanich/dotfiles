# What this repo inherits, and what it owes

This flake has one input. Everything it builds with comes from there, which
buys atomic version bumps and costs you the ability to override anything.

## One input

`upstream.inputs` is merged into this flake's `inputs` under the bare names, so
`inputs.nixpkgs`, `inputs.darwin` and `inputs.sops-nix` all resolve, and a
flake-parts module copied from the upstream repo works unchanged.

Two consequences:

- **`follows` is not available.** You cannot pin a different nixpkgs here. That
  is the point: the modules you import were evaluated against the upstream's
  nixpkgs, and a second one would let them disagree. nix-darwin asserts that
  its release matches nixpkgs, so a skew surfaces as a confusing eval error
  rather than a version warning.
- **`nix flake update` moves everything at once**, because there is one lock
  entry. Bumping nixpkgs is the upstream repo's decision, not this one's.

## What the upstream has to provide

Three outputs, all of which the dendritic layout produces:

| output    | used for                                                          |
| --------- | ----------------------------------------------------------------- |
| `modules` | `flake.modules.{nixos,darwin,homeManager}`, merged in `hosts.nix` |
| `lib`     | nixpkgs lib plus `lib.my.*` (`sshKeys`, `relativeToRoot`, …)      |
| `inputs`  | nixpkgs, darwin, home-manager, sops-nix, flake-parts, import-tree |

`modules/flake-parts/nixpkgs.nix` also imports the upstream's `overlays/`
wholesale, so a package resolves here exactly as it does there.

## home-manager gets the system's pkgs

`modules/users/example.nix` passes `pkgs` through `extraSpecialArgs`
deliberately. Without it home-manager builds its own nixpkgs with no overlays,
and any upstream home module that reaches for an overlaid package fails:

```
error: attribute 'sops-install-secrets' missing
```

Delete that line and the whole home side breaks in a way that reads like an
upstream bug. It isn't.

## `self` must be ours

`flake.nix` merges upstream's inputs but keeps this repo's own `self`:

```nix
inputs = upstream.inputs // inputs;
```

`self` is what `machines/` is resolved relative to. Passing `self = upstream`
makes this flake enumerate the _upstream's_ machines, and
`nixosConfigurations` comes back holding that repo's hosts alongside, or
instead of, yours.

## Secrets: the keys a module drags in

Secrets are declared in _modules_, not machine files, so importing a module
imports its key requirements. A minimal host already needs:

| key                   | comes from                             |
| --------------------- | -------------------------------------- |
| `passwords/<user>`    | `modules/users/<user>.nix` (this repo) |
| `private_keys/<user>` | same                                   |

That is the whole list for the scaffolded machine. The upstream's homeManager
`sops` module declares no secrets of its own — it is wiring only — so importing
it costs nothing. Its `apiKeys` module is where the six `api_keys/*` provider
tokens live, and `home-profiles/example/` leaves it out precisely so this repo
does not owe them.

Every one of those names must exist in this repo's `sops/secrets.yaml`. With
`sops.validateSopsFiles = true`, a missing key fails the build rather than the
activation:

```
sops-install-secrets: manifest is not valid: secret private_keys/example in
/nix/store/…-secrets.yaml is not valid: the key 'private_keys' cannot be found
```

Treat the key names as part of each module's interface. Adding an upstream
module to a machine here means adding its keys to `sops/secrets.yaml` too.

Three settings in `machines/<class>/<host>/configuration.nix` make this work at
all:

| setting                                      | why                                                                                                  |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `sops.defaultSopsFile = …/sops/secrets.yaml` | the upstream's path resolves to _its_ secrets file, whose recipients do not include this machine     |
| `sops.age.keyFile = null`                    | the upstream defaults it to a clan-provisioned `/var/lib/sops-nix/key.txt` that nothing here creates |
| `sops.age.sshKeyPaths = [ … ]`               | what replaces it: an age key derived from the host's own SSH host key                                |

The upstream sets the first two at priority 900 (`lib.mkOverride 900`)
precisely so a plain assignment here wins. If a future upstream change makes
one a plain assignment instead, the symptom is `has conflicting definition
values` and the fix belongs upstream, not in a `mkForce` here.

## What does not cross the boundary

These hosts are not in the upstream's clan inventory, so they cannot be a peer
in its wireguard instance, a borgbackup client of its server, a syncthing peer,
or a holder of its sshd CA certificates. Anything of that sort has to be
configured here, host by host.

If a private machine genuinely needs to join the upstream's fleet services, the
two repos have to become one clan, which means one secrets store: either the
public repo holds the private machines' secrets, or every machine's move here.
