# Keeping machines out of a public repo

Two ways to split public architecture from private hosts. Which one is right depends on a single question:

**Does this flake need to stay evaluable by people who lack access to the private repo?**

If it serves a `templates` output, is a portfolio piece, or gets cloned by anyone but you: yes, and you want route B. Otherwise route A is less machinery.

## Route A — private flake input (simple)

Declare the input, and private machines and modules join this flake's outputs:

```nix
# flake.nix
private.url = "git+ssh://git@github.com/you/nix-private";
```

```nix
# nix-private/flake.nix — no inputs of its own
outputs = _: {
  machines.nixos.secret-host = ./machines/secret-host/configuration.nix;
  modules.nixos.vpnTopology  = ./modules/vpn-topology.nix;
  flakeModules.default       = ./flake-modules/private.nix;
};
```

`modules/flake-parts/private.nix` merges the modules and flake-parts module; `systems.nix` merges the machines. All three exports are optional. Deploy as usual: `nixos-rebuild switch --flake .#secret-host`.

**The cost, measured:** once the input is declared, _every_ output of this flake needs it, including ones that never reference it. Evaluating the module tree touches `inputs.private`, so someone without access gets:

```
$ nix eval .#templates.mini.description
error: Failed to fetch git repository 'ssh://git@github.invalid/nope/private'

$ nix flake init -t path:…#mini
error: Failed to fetch git repository 'ssh://git@github.invalid/nope/private'
```

`nix flake init` wrote nothing. A committed `flake.lock` doesn't help — the lock entry points at a repo they still can't fetch.

## Route B — deploy from the private flake (keeps this repo public)

Reverse the dependency. This flake exports `lib.mkHost`; the private flake consumes it and owns its own `nixosConfigurations`. Nothing here refers to anything private.

```nix
# nix-private/flake.nix
{
  description = "Private machines";

  inputs.dotfiles.url = "github:you/dotfiles";

  outputs =
    { dotfiles, ... }:
    {
      nixosConfigurations.secret-host = dotfiles.lib.mkHost {
        class = "nixos";
        path = ./machines/secret-host/configuration.nix;
        # importable by name inside that machine
        namedModules.nixos.vpnTopology = ./modules/vpn-topology.nix;
      };
    };
}
```

The machine file is an ordinary one and sees the same `specialArgs` local hosts do:

```nix
{ modules, ... }:
{
  imports = with modules.nixos; [ base sops example vpnTopology ];
  networking.hostName = "secret-host";
  nixpkgs.hostPlatform = "x86_64-linux";
}
```

`base`, `sops` and `example` come from the public flake; `vpnTopology` is private. Deploy from the private repo:

```bash
nixos-rebuild switch --flake ~/src/nix-private#secret-host
```

`mkHost` arguments:

| arg            | meaning                                         |
| -------------- | ----------------------------------------------- |
| `class`        | `"nixos"` or `"darwin"` — picks the builder     |
| `path`         | the machine's `configuration.nix`               |
| `extraModules` | extra modules appended to the import list       |
| `namedModules` | merged into the `modules` specialArg, per class |
| `specialArgs`  | overrides merged over the defaults              |

Trade-off: two repos and two deploy targets. Public hosts stay `nixos-rebuild --flake .#host` from here; private ones come from over there.

## Route C — git submodule

Keeps one repo and one deploy command, at the cost of a submodule. Point a guarded reader at a path that only exists when the submodule is checked out:

```nix
imports = lib.optional (builtins.pathExists ../../private/flake-module.nix) ../../private/flake-module.nix;
```

Without `?submodules=1` the files aren't in the store copy, the guard is false, and the flake evaluates clean for anyone. With it, private hosts appear:

```bash
nix flake init -t <repo>#tmpl                             # stranger: exit 0
nix eval .#nixosConfigurations                            # ["example-nixos"]
nix eval '.?submodules=1#nixosConfigurations'             # ["example-nixos","secret-host"]
nixos-rebuild switch --flake '.?submodules=1#secret-host'
```

No lock entry and no fetch, so there's nothing to be denied. Forgetting `?submodules=1` silently gives you the public-only view, which is the sharp edge.

## Does any of this break `nix flake init -t`?

Only route A does, and only for people without access. Init itself copies files and never locks — verified against a template that declared an unreachable input: `nix flake init -t` returned **exit 0** and wrote every file, while `nix flake lock` in the result failed. What breaks route A is the _serving_ flake needing the input at eval time, not the initialized copy.

So the rule for a repo that serves a template: never declare a private input in it. Route B and C both respect that.

## Layout trap

Keep machine files **outside** any directory swept by import-tree. A `configuration.nix` under `modules/` gets loaded as a flake-parts module and fails with an infinite-recursion error, because machine configs reference `modules` in their `imports`.

## Access and auth

`git+ssh://` authenticates with your SSH agent, which is the least friction. The `github:you/nix-private` form needs a token instead:

```
access-tokens = github.com=ghp_...
```

Deploy hosts need their own access only if they evaluate the flake themselves. Build locally and push closures (`nixos-rebuild --target-host`) and only your workstation needs the key.

Local iteration against an uncommitted private checkout:

```bash
nix flake lock --override-input private path:/home/you/src/nix-private   # route A
nixos-rebuild build --flake ~/src/nix-private#secret-host                # route B, just edit in place
```

## What still leaks

Route A publishes the private repo's URL, revision and commit timestamps in `flake.lock`; route C publishes URL and pinned commit in `.gitmodules`. Contents stay private either way. Route B leaks nothing from the public side — the private flake's lock is in the private repo.

## Secrets, and the trap in route B

A private repo is not an encryption strategy; secrets still belong in sops.

The trap: `sops.defaultSopsFile` is a path resolved where the _module_ is written, not where the host is defined. A host built in your private flake that imports the public `sops` module inherits the **public** repo's `sops/secrets.yaml`:

```
$ nix eval --raw .#nixosConfigurations.secret-host.config.sops.defaultSopsFile
/nix/store/…-sops/secrets.yaml          # ← the public repo's copy
```

Activation would then run `sops-install-secrets` against that file. Against the shipped placeholder it fails outright; against a real public file it fails unless the private host's age key is one of its recipients — which is exactly the coupling you were trying to avoid.

Point it at your own file from the private side. The public module marks its defaults with `mkDefault`, so this is a plain assignment, no `mkForce`:

```nix
# nix-private/machines/secret-host/configuration.nix
{ modules, ... }:
{
  imports = with modules.nixos; [ base sops example vpnTopology ];

  sops.defaultSopsFile = ../../sops/secrets.yaml;   # this repo's own
  # sops.validateSopsFiles = true;
}
```

Individual secrets have no hardcoded `sopsFile` either, so they follow along:

```
$ nix eval --raw .#…config.sops.secrets."passwords/example".sopsFile
/nix/store/…-secrets.yaml               # ← the private repo's copy
```

With more than one private host, put that line in a private module and import it everywhere rather than repeating it.

**Repointing the file doesn't repoint the requirements.** Every module you import brings its declared key names with it — `modules/users/example.nix` alone demands `passwords/example` and `private_keys/example` — so the private `secrets.yaml` must contain each one. Set `sops.validateSopsFiles = true` and a missing key is a build error:

```
sops-install-secrets: manifest is not valid: secret private_keys/example in
/nix/store/…-secrets.yaml is not valid: the key 'private_keys' cannot be found
```

Leave it false and that config builds clean, then fails partway through `nixos-rebuild switch`. Either audit the imported modules for the keys they declare, or let the build tell you.

For a key that genuinely belongs elsewhere, override just that one rather than the default:

```nix
sops.secrets."api_keys/shared".sopsFile = "${inputs.dotfiles}/sops/secrets.yaml";
```

That works only if the private host's age key is a recipient of the public file — which is the coupling to avoid unless you actually want it.

The rest follows normally: `sops/.sops.yaml` in the private repo lists your admin key plus each private host's age key, and `sops updatekeys` runs in whichever repo owns the file. The two `.sops.yaml` files are independent — a public host never needs to decrypt a private secret, and vice versa.

Home-manager secrets work the same way; override `sops.defaultSopsFile` inside the home profile the private host uses.
