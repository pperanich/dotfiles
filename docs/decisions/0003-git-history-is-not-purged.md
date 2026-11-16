# 0003: Git history is not purged

## Status

Accepted 2026-11-14.

## Context

Older commits hold sops files encrypted to keys this repository no longer uses. The keys were replaced and the credentials those files protected were rotated or revoked. A few low-value items are still on a list to rotate.

Rewriting history with `git filter-repo` to drop those files would mean force-pushing `main` and re-cloning every checkout. It would not remove copies already made: existing clones, forks and any service that has fetched the repository keep the old history.

## Decision

Keep the history as it is. Finish the remaining rotations instead, so the old ciphertext protects nothing still in use.

The branch that carried the key change is squash-merged locally and never pushed. Its intermediate commits, which hold files encrypted to keys from the middle of that change, stay out of the public history.

## Consequences

- No force-push and no re-clone on any machine.
- Anyone with an old key and the old history can still read the old values, so every credential in those files has to stay rotated. The remaining rotations are tracked in `docs/todo.md`.
