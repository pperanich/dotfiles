#!/usr/bin/env bash
# Show what each host would compile instead of downloading, before you deploy.
# Dry-runs every host's system, then keeps only derivations that really build:
# not a fetch (outputHash), not a local trivial step (preferLocalBuild), with a src.
#
#   bin/build-report.sh                 the Mac and every deploy-rs node
#   bin/build-report.sh pp-nas1 pp-ml1  only the named hosts
#
# It answers "what is not in a binary cache" from this machine's store and substituters, so a
# Linux host may already hold some of what it lists from an earlier build on the host itself.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if (($# > 0)); then
  hosts=("$@")
else
  mapfile -t hosts < <(
    nix eval --json .#darwinConfigurations --apply builtins.attrNames | jq -r '.[]'
    nix eval --json .#deploy.nodes --apply builtins.attrNames | jq -r '.[]'
  )
fi

darwin_hosts=$(nix eval --json .#darwinConfigurations --apply builtins.attrNames)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for host in "${hosts[@]}"; do
  if jq -e --arg h "$host" 'index($h)' <<<"$darwin_hosts" >/dev/null; then
    attr=".#darwinConfigurations.$host.system"
  else
    attr=".#nixosConfigurations.$host.config.system.build.toplevel"
  fi

  if ! nix build --dry-run --no-link "$attr" >"$tmp/out" 2>&1; then
    echo "== $host: evaluation failed"
    grep -m3 'error' "$tmp/out" | sed 's/^/   /'
    continue
  fi

  sed -n '/will be built/,/will be fetched/p' "$tmp/out" |
    grep -oE '/nix/store/[a-z0-9]{32}-[^ ]+\.drv' | sort -u >"$tmp/drvs" || true

  compiles=()
  if [[ -s $tmp/drvs ]]; then
    mapfile -t compiles < <(
      xargs nix derivation show <"$tmp/drvs" 2>/dev/null |
        jq -r '.derivations[] | select((.env.outputHash // "") == ""
            and (.env.preferLocalBuild // "") != "1"
            and ((.env.src // "") != "" or (.env.srcs // "") != "")) | .name' |
        grep -v '^bun-pkg--' | sort -u
    )
  fi

  echo "== $host: $(wc -l <"$tmp/drvs" | tr -d ' ') to build, ${#compiles[@]} compile"
  ((${#compiles[@]} == 0)) || printf '   %s\n' "${compiles[@]}"
done
