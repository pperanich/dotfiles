#!/usr/bin/env bash
# Show what each host would compile instead of downloading, before you deploy.
# Dry-runs every host's system, then keeps only derivations that really build:
# not a fetch, not a local trivial step (preferLocalBuild), with a src.
#
#   bin/build-report.sh                 the Mac and every deploy-rs node
#   bin/build-report.sh pp-nas1 pp-ml1  only the named hosts
#   bin/build-report.sh --local ...     skip asking NixOS hosts what their store already holds
#
# For a NixOS host it asks <host>.pp-ts over ssh (root, as deploy does) which outputs it already
# has, and drops those along with anything only they needed. An unreachable host falls back to
# this machine's store and substituters, which can list builds the host already holds.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

local_only=false
if [[ ${1:-} == --local ]]; then
  local_only=true
  shift
fi

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
export NIX_SSHOPTS="${NIX_SSHOPTS:-} -o ConnectTimeout=10 -o BatchMode=yes"

for host in "${hosts[@]}"; do
  darwin=false
  if jq -e --arg h "$host" 'index($h)' <<<"$darwin_hosts" >/dev/null; then
    darwin=true
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
  if [[ ! -s $tmp/drvs ]]; then
    echo "== $host: nothing to build"
    continue
  fi

  xargs nix derivation show <"$tmp/drvs" 2>/dev/null | jq -s 'map(.derivations) | add' >"$tmp/show.json"
  top=$(nix eval --raw "$attr.drvPath")

  # Outputs the host already holds; an empty list means "this machine's view".
  view="this machine's store"
  : >"$tmp/held"
  if ! $darwin && ! $local_only; then
    jq -r '.[].outputs[].path // empty | "/nix/store/" + .' "$tmp/show.json" | sort -u >"$tmp/outs"
    if xargs nix-store --store "ssh-ng://root@$host.pp-ts" --check-validity --print-invalid \
      <"$tmp/outs" >"$tmp/missing" 2>"$tmp/err"; then
      comm -23 "$tmp/outs" <(sort -u "$tmp/missing") >"$tmp/held"
      view="$host's store"
    else
      view="this machine's store ($host unreachable: $(head -c 120 "$tmp/err" | tr '\n' ' '))"
    fi
  fi

  # Walk from the system derivation, only into outputs the host lacks, so the build inputs of
  # something already present (boost under mongodb) drop out.
  jq -r --arg top "${top##*/}" --rawfile held "$tmp/held" '
    . as $d
    | ($held | split("\n") | map(select(. != "") | ltrimstr("/nix/store/") | {(.): true}) | add // {}) as $have
    | def deps($n): ($d[$n].inputs.drvs // $d[$n].inputDrvs // {}) | to_entries[]
        | select($d[.key] != null) | .key as $k | (.value.outputs // .value)[] | {n: $k, o: .};
      def attr($k): .env[$k] // .structuredAttrs[$k];
      {queue: [{n: $top, o: "out"}], seen: {}, need: {}}
      | until(.queue == [];
          .queue[0] as $x | .queue |= .[1:]
          | ($x.n + "!" + $x.o) as $key
          | if .seen[$key] or $d[$x.n] == null then .
            else .seen[$key] = true
              | ($d[$x.n].outputs[$x.o].path // null) as $p
              | if $p != null and $have[$p] then .
                else .need[$x.n] = true | .queue += [deps($x.n)] end
            end)
      | .need | keys[] | $d[.]
      | select((.outputs | all(.hash == null)) and (attr("outputHash") // "") == ""
          and ((attr("preferLocalBuild") // false) | tostring | IN("1", "true") | not)
          and ((attr("src") // attr("srcs")) | . != null and . != "" and . != []))
      | .name' "$tmp/show.json" | grep -v '^bun-pkg--' | sort -u >"$tmp/compiles" || true

  echo "== $host: $(wc -l <"$tmp/drvs" | tr -d ' ') to build here, $(wc -l <"$tmp/compiles" | tr -d ' ') compile on $view"
  sed 's/^/   /' "$tmp/compiles"
done
