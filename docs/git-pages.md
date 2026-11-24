# Git Pages (`*.pages.prestonperanich.com`)

Self-hosted static documentation and project sites powered by [`git-pages`](https://codeberg.org/git-pages/git-pages) on `pp-router1`, fronted by Caddy over LAN and Tailscale (private only, matching Gitea).

## URL Layout

`git-pages` uses the standard multi-owner GitHub/Codeberg Pages layout:

| Site              | URL                                                 | Matching Gitea Repository                                      |
| ----------------- | --------------------------------------------------- | -------------------------------------------------------------- |
| Project docs      | `https://<owner>.pages.prestonperanich.com/<repo>/` | `https://gitea.prestonperanich.com/<owner>/<repo>.git`         |
| Owner / org index | `https://<owner>.pages.prestonperanich.com/`        | `https://gitea.prestonperanich.com/<owner>/pages.git`          |
| Apex redirect     | `https://pages.prestonperanich.com/`                | 302 redirect to `https://pperanich.pages.prestonperanich.com/` |

Adding a new repository's docs requires no NixOS, Caddy, or DNS changes—just publish from Gitea Actions.

### Static Site Generator Base Paths

Because project sites live under `/<repo>/`, configure the generator's base path to match the repository name:

| Tool                 | Setting                                                                                         |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| MkDocs               | `site_url: https://pperanich.pages.prestonperanich.com/<repo>/` (or `use_directory_urls: true`) |
| VitePress            | `base: '/<repo>/'` in `.vitepress/config.ts`                                                    |
| Astro / Starlight    | `base: '/<repo>'` in `astro.config.mjs`                                                         |
| Docusaurus           | `baseUrl: '/<repo>/'` in `docusaurus.config.js`                                                 |
| Hugo                 | `baseURL = 'https://pperanich.pages.prestonperanich.com/<repo>/'`                               |
| mdBook / `cargo doc` | Works with relative paths out of the box                                                        |

## Authorization

`git-pages` is configured with `authorization = "gitea"` and `allowed-repository-url-prefixes = ["https://gitea.prestonperanich.com/"]`. On any `PUT`, `PATCH`, or `DELETE` request, it reads the `Forge-Authorization` header and verifies against Gitea's API:

1. `GET /api/v1/repos/<owner>/<repo>` returns `permissions.push == true`.
2. `GET /api/v1/user` identifies the publishing user for the audit log.

### Token Setup

Try Gitea's automatic per-job token (`${{ github.token }}`) first. If your Gitea version denies `/api/v1/user` to Actions task tokens, create a single Personal Access Token instead:

1. In Gitea, open **Settings → Applications → Access Tokens**.
2. Grant **Read** on `user` and **Read and Write** on `repository`, then generate the token.
3. Store it once as an Actions secret named `GIT_PAGES_TOKEN` (under your user/org Actions settings so every repo inherits it).

You can test authorization non-destructively with `Dry-Run: yes`:

```bash
curl -i -X PUT \
  -H "Dry-Run: yes" \
  -H "Forge-Authorization: token <TOKEN>" \
  -H "Content-Type: application/x-tar" \
  "https://pperanich.pages.prestonperanich.com/<repo>/"
```

Expect `200 OK` with `dry-run ok`.

## Publishing from Gitea Actions (`pp-wsl1`)

### Option 1: Zero-dependency `tar` + `curl` (Docker or `native:host`)

```yaml
name: Publish Docs
on:
  push:
    branches: [main]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build docs
        run: |
          # Replace with your build command outputting into dist/
          mkdir -p dist
          cp -r docs/* dist/
      - name: Publish to git-pages
        env:
          # Switch to secrets.GIT_PAGES_TOKEN if Gitea restricts github.token on /api/v1/user
          TOKEN: ${{ secrets.GIT_PAGES_TOKEN || github.token }}
        run: |
          tar -cf site.tar -C dist .
          curl --fail-with-body -X PUT \
            -H "Forge-Authorization: token ${TOKEN}" \
            -H "Content-Type: application/x-tar" \
            --data-binary @site.tar \
            "https://${{ github.repository_owner }}.pages.prestonperanich.com/${{ github.event.repository.name }}/"
```

### Option 2: `git-pages-cli` on `native`

`git-pages-cli` is pre-installed in `pp-wsl1`'s runner `hostPackages` and supports `--pretty-urls`, `--comment`, and `--dry-run`:

```yaml
jobs:
  docs:
    runs-on: native
    steps:
      - uses: actions/checkout@v4
      - run: nix build .#docs -o dist
      - name: Publish to git-pages
        env:
          GIT_PAGES_TOKEN: ${{ secrets.GIT_PAGES_TOKEN || github.token }}
        run: |
          git-pages-cli \
            "https://${{ github.repository_owner }}.pages.prestonperanich.com/${{ github.event.repository.name }}/" \
            --upload-dir dist \
            --pretty-urls \
            --comment "${{ github.sha }}"
```

### Option 3: Official `git-pages/action`

```yaml
- uses: https://codeberg.org/git-pages/action@v2
  with:
    site: https://${{ github.repository_owner }}.pages.prestonperanich.com/${{ github.event.repository.name }}/
    token: ${{ secrets.GIT_PAGES_TOKEN || github.token }}
    source: dist/
    strict: true
    pretty-urls: true
    comment: ${{ github.sha }}
```

### Unpublishing a Site

```bash
curl --fail-with-body -X DELETE \
  -H "Forge-Authorization: token <TOKEN>" \
  "https://pperanich.pages.prestonperanich.com/<repo>/"
```

## Site Features

- **Redirects & SPAs (`_redirects`):** Place a Netlify-style `_redirects` file in the site root (e.g. `/* /index.html 200` for client-side routing).
- **Custom 404:** Place a `404.html` in the site root.
- **Health endpoint:** Each published site responds `200 ok` at `/.git-pages/health`.

## Homelab Plumbing

| Concern                                                                       | Location                                |
| ----------------------------------------------------------------------------- | --------------------------------------- |
| NixOS module (`my.gitPages`, ports `3020`/`3022`)                             | `modules/services/git-pages.nix`        |
| Router enablement, Unbound `extraLocalZones`, Blackbox probes, backup path    | `machines/pp-router1/configuration.nix` |
| Caddy wildcard/apex vhosts and Cloudflare `AAAA` records (`pages`, `*.pages`) | `machines/pp-router1/caddy.nix`         |
| Unbound `extraLocalZones` support (`_acme-challenge` transparent carve-out)   | `modules/router/dns.nix`                |
| Runner `git-pages-cli` package                                                | `modules/services/gitea-runner.nix`     |

### Operations & Troubleshooting

- **Service & logs (on `pp-router1`):** `systemctl status git-pages` and `journalctl -u git-pages -f` (also shipped to Loki).
- **Metrics:** Scraped by Prometheus at `127.0.0.1:3022/metrics` (`job="git-pages"`).
- **TLS cert monitoring:** Blackbox probes `https://pages.prestonperanich.com/.well-known/git-pages-health` and `https://probe.pages.prestonperanich.com/.well-known/git-pages-health`.
- **State & backups:** Stored under `/var/lib/private/git-pages/data` (`DynamicUser = true`), included in `pp-router1`'s nightly Borg and Google Drive backups.
