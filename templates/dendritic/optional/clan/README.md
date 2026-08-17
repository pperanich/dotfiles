# Optional: clan-core

Without clan, `modules/flake-parts/systems.nix` builds `nixosConfigurations` / `darwinConfigurations` from the `machines/` tree and you deploy with `nixos-rebuild --flake .#host` or `darwin-rebuild`.

clan replaces that with an inventory: machines get tags, services get applied to tags, and per-machine secrets (host SSH keys, age keys, user passwords, wireguard keys) are generated and deployed by `clan vars` instead of by hand. Worth it once you have more than two or three machines.

## Switching

1. Uncomment the `clan-core` input in `flake.nix`.
2. Flatten the machines tree — clan expects `machines/<host>/`, not `machines/<class>/<host>/`:

   ```bash
   git mv machines/nixos/example-nixos machines/example-nixos
   git mv machines/darwin/example-darwin machines/example-darwin
   rmdir machines/nixos machines/darwin
   ```

   clan looks for `machines/<host>/configuration.nix`, which is already the filename used here.

3. Delete `modules/flake-parts/systems.nix` — clan produces both config outputs, and leaving it in place makes two modules fight over the same attribute.
4. Copy `clan.nix` from this directory to `modules/flake-parts/clan.nix` and edit the inventory.
5. Set each machine's deploy target in its `configuration.nix`:

   ```nix
   clan.core.networking.targetHost = "root@example-nixos";
   ```

## After switching

```bash
nix develop                       # clan-cli, now that the input is declared
clan machines list
clan vars generate example-nixos  # machine keys, passwords
clan machines update example-nixos
```

`modules/flake-parts/shell.nix` adds `clan-cli` to the dev shell only when the
`clan-core` input exists, so the shell is unchanged until you finish step 1.

On Determinate Nix, `clan machines update` can fail with `KeyError: 'path'`.
clan reads the `path` key from `nix flake metadata --json`, which lazy trees
omits, and clan-cli puts its own pinned nix ahead of yours on PATH. Either run
clan with `--option lazy-trees false`, or override the nix it wraps:

```nix
clan-cli = inputs.clan-core.packages.${system}.clan-cli.override { nix = <your nix>; };
```

## sops interaction

Both systems coexist, and it's worth being clear about which owns what:

- **clan vars** — bootstrap secrets clan generates for you (host keys, the machine age key at `/var/lib/sops-nix/key.txt`, user passwords).
- **sops/secrets.yaml** — secrets you author (API tokens, service passwords).

If you use clan, point the sops modules at the clan-managed key instead of the host SSH key:

```nix
sops.age.keyFile = "/var/lib/sops-nix/key.txt";
```

and add each machine's clan-generated age key (`clan vars get <machine> ...`, or read it from `vars/`) to `sops/.sops.yaml` as a recipient.
