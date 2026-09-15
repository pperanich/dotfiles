# Optional remote deployment

deploy-rs builds and activates hosts over SSH. With `magicRollback`, the
target rolls back if the client cannot confirm the activation, for example
after a network or SSH configuration change breaks access. `autoRollback`
also requests rollback when activation fails.

## Enable

1. Uncomment `inputs.deploy-rs.url` in the root `flake.nix`.
2. Copy the module into the auto-imported tree:

   ```bash
   cp optional/deploy-rs/deploy.nix modules/flake-parts/deploy.nix
   ```

3. Edit the copied module: rename the nodes and configuration references,
   replace `sshUser`, and set each hostname or SSH alias. Delete the node
   for any example machine you removed. The activation helper reads each
   machine's platform, so architecture changes need no second platform pin.
4. Track the new module and lock the added input:

   ```bash
   git add flake.nix modules/flake-parts/deploy.nix
   nix flake update deploy-rs
   nix develop
   ```

The shell adds the CLI when the deploy-rs input is present. The default template
does not fetch deploy-rs or expose deployment nodes until these steps.

## Deploy

Bootstrap the host and secrets using the root README first. The target needs
a working Nix installation, SSH access, and the declared user account.
Review the build before activation:

```bash
deploy --dry-activate .#example-nixos
deploy .#example-nixos
# Or:
deploy .#example-darwin
```

The example evaluates locally and builds on the target with
`remoteBuild = true`. The local machine therefore need not match the
target architecture. SSH must allow the configured user to run sudo; the
example prompts with `interactiveSudo = true`. macOS Touch ID cannot satisfy
that prompt over SSH, so use the account password.

For unattended deployments, use a deliberately configured noninteractive
sudo policy and set `interactiveSudo = false`. This template does not change
the host's sudo policy for you. SSH aliases can supply `ProxyCommand` for
tunnels; verify the alias works before deploying.

Rollback restores the system profile. It cannot undo arbitrary external
effects from activation hooks, such as package-manager updates or files
written by applications. Allow enough activation and confirmation time for
your connection and hooks before relying on it for connectivity changes.

## Package versions and checks

The extra input supplies deploy-rs's activation helpers, while the CLI and
activation binary come from upstream nixpkgs. Its independent nixpkgs pin
does not become part of the target system.

The CLI validates its schema at invocation. The example leaves
`deployChecks` out of `flake.checks`, so enabling it does not add remote
architecture builds to the local check suite. Evaluate both configuration
derivations and use dry activation before your first real deployment.

On-host `nh os switch` and `nh darwin switch` remain available. Their
platform-specific defaults still point at the private checkout.
