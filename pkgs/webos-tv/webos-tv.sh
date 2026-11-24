# shellcheck shell=bash
set -euo pipefail

device="${WEBOS_DEVICE:-pp-tv1}"
host="${WEBOS_HOST:-pp-tv1.home.arpa}"
moonlight_repo="mariotaku/moonlight-tv"
moonlight_app_id="com.limelight.webos"

usage() {
	cat >&2 <<'EOF'
usage: webos-tv [-d DEVICE] [-H HOST] <command> [args...]

Commands:
  pair [HOST]                    Register TV, fetch Key Server SSH key, verify info
  info                           Show TV system info and installed apps
  apps                           List installed apps
  install-moonlight [TAG|FILE]   Install latest (or tagged/local) Moonlight .ipk
  launch [APP_ID]                Launch Moonlight (or another app ID)
  token                          Print raw Dev Mode session token (for piping to sops)
  check-session                  Check remaining Dev Mode hours via LG API
  renew-session                  Renew Dev Mode session via LG API and verify hours

Environment:
  WEBOS_DEVICE  Device profile name (default: pp-tv1)
  WEBOS_HOST    TV hostname or IP (default: pp-tv1.home.arpa)
EOF
	exit 2
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-d | --device)
		[[ $# -ge 2 ]] || usage
		device="$2"
		shift 2
		;;
	-H | --host)
		[[ $# -ge 2 ]] || usage
		host="$2"
		shift 2
		;;
	-h | --help) usage ;;
	--)
		shift
		break
		;;
	-*)
		echo "webos-tv: unknown option '$1'" >&2
		usage
		;;
	*) break ;;
	esac
done

[[ $# -ge 1 ]] || usage
cmd="$1"
shift

device_exists() {
	local line name
	while IFS= read -r line || [[ -n $line ]]; do
		name="${line%%[[:space:]]*}"
		if [[ $name == "$device" ]]; then
			return 0
		fi
	done < <(ares-setup-device --list | tail -n +3)
	return 1
}

fetch_token() {
	local line token=""
	# ares-novacom prints "[Info] Set target device : ..." on stdout ahead of remote output.
	while IFS= read -r line || [[ -n $line ]]; do
		line="${line//$'\r'/}"
		[[ -n $line && $line != "[Info]"* ]] || continue
		token="$line"
	done < <(ares-novacom --run "cat /var/luna/preferences/devmode_enabled" -d "$device")
	if [[ -z $token ]]; then
		echo "webos-tv: failed to read /var/luna/preferences/devmode_enabled from $device" >&2
		exit 1
	fi
	printf '%s' "$token"
}

ensure_writable_webos_config() {
	# Nix's ares-cli seeds ~/.webos files from the read-only store (0444); make them 0600 before writes.
	local f
	for f in "$HOME/.webos"/tv/novacom-devices.json "$HOME/.webos"/ose/novacom-devices.json "$HOME/.webos"/config.json; do
		if [[ -f $f && ! -w $f ]]; then
			chmod 600 "$f"
		fi
	done
}

cmd_pair() {
	local target_host="${1:-$host}"
	local exists=0
	if device_exists; then
		exists=1
	fi
	ensure_writable_webos_config
	if [[ $exists -eq 1 ]]; then
		ares-setup-device -m "$device" -i "username=prisoner" -i "host=$target_host" -i "port=9922"
		ares-setup-device -f "$device"
	else
		ares-setup-device -a "$device" -i "username=prisoner" -i "host=$target_host" -i "port=9922" -i "default=true"
	fi
	echo "Make sure Developer Mode and Key Server are ON in the TV app, then enter the 6-character passphrase." >&2
	ares-novacom --getkey -d "$device"
	ares-device -i -d "$device"
}

tmpdir=""
cleanup() {
	if [[ -n $tmpdir ]]; then
		rm -rf -- "$tmpdir"
	fi
}
trap cleanup EXIT

cmd_install_moonlight() {
	local target="${1:-latest}"
	if [[ -f $target ]]; then
		echo "Installing local package $target to $device..." >&2
		ares-install "$target" -d "$device"
		return
	fi

	local api_url
	if [[ $target == "latest" ]]; then
		api_url="https://api.github.com/repos/$moonlight_repo/releases/latest"
	else
		api_url="https://api.github.com/repos/$moonlight_repo/releases/tags/$target"
	fi

	tmpdir=$(mktemp -d)

	local release_json tag ipk_url ipk_name manifest_url
	release_json=$(curl --silent --show-error --fail --location "$api_url")
	tag=$(jq -er '.tag_name' <<<"$release_json")
	ipk_name=$(jq -er '.assets[] | select(.name | test("^com\\.limelight\\.webos_.*_arm\\.ipk$")) | .name' <<<"$release_json" | head -n 1)
	ipk_url=$(jq -er --arg name "$ipk_name" '.assets[] | select(.name == $name) | .browser_download_url' <<<"$release_json")
	manifest_url=$(jq -r '.assets[] | select(.name == "com.limelight.webos.manifest.json") | .browser_download_url' <<<"$release_json" | head -n 1)

	local ipk_path="$tmpdir/$ipk_name"
	echo "Downloading Moonlight $tag ($ipk_name)..." >&2
	curl --silent --show-error --fail --location --output "$ipk_path" "$ipk_url"

	if [[ -n $manifest_url ]]; then
		local expected_sha actual_sha
		expected_sha=$(curl --silent --show-error --fail --location "$manifest_url" | jq -r '.ipkHash.sha256 // empty')
		if [[ -n $expected_sha ]]; then
			actual_sha=$(sha256sum "$ipk_path" | cut -d' ' -f1)
			if [[ $actual_sha != "$expected_sha" ]]; then
				echo "webos-tv: SHA-256 mismatch for $ipk_name (expected $expected_sha, got $actual_sha)" >&2
				exit 1
			fi
			echo "Verified SHA-256 ($actual_sha)." >&2
		fi
	fi

	echo "Installing $ipk_name to $device..." >&2
	ares-install "$ipk_path" -d "$device"
}

case "$cmd" in
pair)
	cmd_pair "${1:-}"
	;;
info)
	ares-device -i -d "$device"
	echo ""
	ares-install -l -d "$device"
	;;
apps)
	ares-install -l -d "$device"
	;;
install-moonlight)
	cmd_install_moonlight "${1:-latest}"
	;;
launch)
	ares-launch "${1:-$moonlight_app_id}" -d "$device"
	;;
token)
	fetch_token
	;;
check-session)
	fetch_token | webos-devmode-renew --token-file - --check-only "$@"
	;;
renew-session)
	fetch_token | webos-devmode-renew --token-file - "$@"
	;;
*)
	echo "webos-tv: unknown command '$cmd'" >&2
	usage
	;;
esac
