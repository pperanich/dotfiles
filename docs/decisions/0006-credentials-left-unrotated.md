# 0006: Credentials left unrotated

## Status

Accepted 2026-11-15. The individual exceptions were decided between 2026-11-13 and 2026-11-15.

## Context

Older commits hold sops files encrypted to keys this repository no longer uses ([0003](0003-git-history-is-not-purged.md)). 0003 keeps that history on the condition that every credential in those files is rotated. After the November 2026 security cutover rotated the rest, four were deliberately left as they were.

## Decision

These keep their current values:

| Credential                                | Why it stays                                                                                                                                                                          |
| :---------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| The three Wi-Fi passphrases               | Every device on a changed SSID would have to rejoin, and the IoT devices need re-pairing through their apps. Using a passphrase still requires being within radio range of the house. |
| `docuseal-secret-key-base`                | DocuSeal derives the keys for its stored signing certificates, settings, access tokens and webhook secrets from it; a new value makes that data unreadable.                           |
| `grafana-secret-key`                      | It encrypts the secrets stored through the Grafana UI, which a new key would make unreadable.                                                                                         |
| The sudo password (`passwords/pperanich`) | Only its hash was in the history, and the password is strong enough against offline cracking.                                                                                         |

## Consequences

- Anyone holding one of the retired keys and a copy of the old history can read these four values.
- Rotate one when a retired key is known to be compromised, or when the thing it protects is rebuilt anyway (new SSIDs, a fresh DocuSeal or Grafana, a new sudo password per host).
- Whether hosts get distinct sudo passwords is still open in `docs/todo.md`.
