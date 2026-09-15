# What this repo inherits, and what it owns

## Inputs and package versions

The default flake has one direct input, `upstream`, whose dependency graph
includes nixpkgs, nix-darwin, Home Manager, and the module tooling.
`nix flake update upstream` advances that public configuration and the
dependency versions it pins.

`flake.nix` passes `upstream.inputs // inputs` to flake-parts. This exposes
the upstream dependencies under their ordinary names while preserving the
private flake's own `self`. Do not replace `self` with `upstream`: paths
and outputs must refer to the private flake.

New direct inputs can be added, and their `follows` paths can target
`upstream/nixpkgs`. Merely overriding an input in the merged argument set
does not retarget upstream modules: those modules already close over their
own inputs. Keep machine packages and upstream modules on the same nixpkgs.

The optional deploy-rs integration adds a second direct input for deployment
helpers. It replaces deploy-rs's package with the one from upstream nixpkgs,
so its independent package pin does not enter the deployed system closure.
Update that input separately with `nix flake update deploy-rs`, or update
both direct inputs with `nix flake update`.

## Required upstream interfaces

| Output or path | Used for                                                                                |
| -------------- | --------------------------------------------------------------------------------------- |
| `modules`      | `modules.{nixos,darwin,homeManager}`, merged per class in `hosts.nix`                   |
| `lib`          | nixpkgs lib and upstream helpers, including `lib.my.sshKeys`                            |
| `inputs`       | nixpkgs, darwin, Home Manager, sops-nix, flake-parts, import-tree, systems, treefmt-nix |
| `overlays/`    | packages for this repo's shell and formatter                                            |

Machine `specialArgs` expose the merged module tree, upstream's extended
`lib`, upstream dependencies, and the private `self` and outputs. Local
modules replace upstream modules of the same class and name, rather than
adding definitions to them. Import the upstream module explicitly if you
want to extend one instead.

Keep machine files outside `modules/`, since import-tree loads everything
there as flake-parts modules. Group reusable modules by topic; a single file
can export NixOS, Darwin, and Home Manager implementations.

## Hosts and home profiles

`hosts.nix` reads `nixpkgs.hostPlatform` directly from each
`machines/<host>/configuration.nix` to choose a builder. It cannot inspect
imports or module-system arguments during this read. A missing platform or
a dependency on `config` or `pkgs` produces an error naming the host.

`modules/users/example.nix` owns account creation and passes the system's
`pkgs` through Home Manager's `extraSpecialArgs`. Otherwise Home Manager
can construct a package set without upstream's overlays, producing errors
such as `attribute 'sops-install-secrets' missing`.

The system's `my.example.desktop` option is also passed explicitly through
`extraSpecialArgs`. The home profile may use that argument to select
imports; reading Home Manager's own `config` inside `imports` recurses.
Every caller must supply the argument. Both platforms use the same profile.

On Darwin, the user module configures trusted users through
`determinateNix.customSettings` when Determinate Nix is enabled and that
option exists. Otherwise it uses `nix.settings`. The active daemon needs
this setting to accept the unsigned paths copied for remote builds.

## Secrets and bootstrap order

Each machine overrides these upstream defaults:

| Setting                | Private value                                      |
| ---------------------- | -------------------------------------------------- |
| `sops.defaultSopsFile` | this repo's `sops/secrets.yaml`                    |
| `sops.age.keyFile`     | `null`, since there is no Clan-provisioned age key |
| `sops.age.sshKeyPaths` | `[ "/etc/ssh/ssh_host_ed25519_key" ]`              |

Upstream sets the first two at priority 900, allowing plain assignments
here. Home Manager independently points `sops.defaultSopsFile` at the
private file.

The system decrypts with its persistent SSH host key, then installs
`private_keys/<user>` as the user's SSH key. Home Manager decrypts with
that installed user key. Encrypt the file to both the host and user/admin
recipients.

**Never make system decryption depend on a key SOPS itself installs.**
The installed key points into runtime storage that disappears at reboot.
On macOS, enable Remote Login and create the host keys before the first
activation, as described in [the setup guide](../README.md).

The NixOS user module requires `passwords/<user>` and
`private_keys/<user>`; Darwin requires only the latter. Every additional
module can introduce more required names. Upstream's Home Manager `sops`
module declares no secrets of its own. With `sops.validateSopsFiles = true`,
a declared key missing from the YAML fails the build before activation.
This validates names and file structure, not the target's ability to decrypt.

The NixOS example also sets `users.mutableUsers = false` explicitly in its
machine file. With its user-management implementation, `true` only applies
the declared password when creating an account; `false` reapplies the SOPS
hash on every activation. The latter also removes undeclared accounts and
groups, so adopting an existing host requires the
[account migration](../README.md#adopting-an-existing-nixos-machine) before
switching. This is a machine-wide policy, not a default in the user module.

After changing recipients, run
`sops --config sops/.sops.yaml updatekeys sops/secrets.yaml`.
The explicit config path matters when running from the repo root.

## Optional API-key discovery

Uncomment `apiKeys` in `home-profiles/example/default.nix` to use the
local replacement in `modules/shell/api-keys.nix`. It declares only the
names under this repo's `api_keys`, without importing upstream's fixed
provider list or decrypting anything during evaluation.

Add tokens using `sops sops/secrets.yaml`. Use a flat mapping with
unquoted shell-variable names, for example `example_api_key`. SOPS writes
the encrypted result as:

```yaml
api_keys:
  example_api_key: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
```

The reader accepts consistent space indentation, comments, CRLF, and
single-line `ENC[...]` values. Omit the section or use `api_keys: {}` when
empty. Duplicate names, nested mappings, quoted names, multiline values,
and populated inline mappings are unsupported and fail with a named error.
This is a reader for that SOPS output shape, not a general YAML parser.

Home Manager installs each value at its `api_keys/<name>` secret path.
Exporting those files as environment variables is the upstream shell
configuration's responsibility; confirm its naming convention before
adding providers.

## Fleet services

These machines do not join upstream's Clan inventory. WireGuard membership,
backup relationships, Syncthing peers, and SSH certificate authorities need
explicit private configuration. Modules that reference `clan.core`
directly cannot be imported into this scaffold without also supplying Clan.
The optional deploy-rs module adds deployment transport and rollback, not
fleet membership.
