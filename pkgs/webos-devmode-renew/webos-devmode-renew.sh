# shellcheck shell=bash
set -euo pipefail

usage() {
	echo "usage: webos-devmode-renew [--token-file PATH|-] [--check-only] [--min-hours N]" >&2
	exit 2
}

token_file=""
check_only=0
min_hours=100
base_url="${WEBOS_DEVMODE_BASE_URL:-https://developer.lge.com/secure}"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--token-file)
		[[ $# -ge 2 ]] || usage
		token_file="$2"
		shift 2
		;;
	--check-only)
		check_only=1
		shift
		;;
	--min-hours)
		[[ $# -ge 2 ]] || usage
		min_hours="$2"
		shift 2
		;;
	-h | --help) usage ;;
	*)
		echo "webos-devmode-renew: unknown option '$1'" >&2
		usage
		;;
	esac
done

if [[ ! $min_hours =~ ^[0-9]+$ ]]; then
	echo "webos-devmode-renew: --min-hours must be a non-negative integer, got '$min_hours'" >&2
	exit 2
fi

if [[ -z $token_file ]]; then
	if [[ -n ${CREDENTIALS_DIRECTORY:-} ]]; then
		token_file="$CREDENTIALS_DIRECTORY/session-token"
	else
		echo "webos-devmode-renew: pass --token-file PATH (or - for stdin)" >&2
		exit 2
	fi
fi

if [[ $token_file == "-" ]]; then
	token=$(tr -d '\r\n')
else
	if [[ ! -r $token_file ]]; then
		echo "webos-devmode-renew: token file not readable: $token_file" >&2
		exit 1
	fi
	token=$(tr -d '\r\n' <"$token_file")
fi

if [[ -z $token ]]; then
	echo "webos-devmode-renew: session token is empty" >&2
	exit 1
fi

# Pass the token via curl's stdin config so it never appears in process arguments.
call_lg() {
	local endpoint="$1"
	local escaped="${token//\\/\\\\}"
	escaped="${escaped//\"/\\\"}"
	printf 'url = "%s"\nget\ndata-urlencode = "sessionToken=%s"\n' "$endpoint" "$escaped" |
		curl --silent --show-error --fail --max-time 30 --config -
}

check_response() {
	local action="$1"
	local body="$2"
	local result code msg
	result=$(jq -er '.result // empty' <<<"$body" 2>/dev/null) || {
		echo "webos-devmode-renew: $action returned non-JSON or missing result" >&2
		exit 1
	}
	code=$(jq -r '.errorCode // ""' <<<"$body")
	msg=$(jq -r '.errorMsg // ""' <<<"$body")
	if [[ $result != "success" ]]; then
		echo "webos-devmode-renew: $action failed (result=$result, code=$code, msg=$msg)" >&2
		exit 1
	fi
	printf '%s' "$msg"
}

if [[ $check_only -eq 0 ]]; then
	reset_body=$(call_lg "$base_url/ResetDevModeSession.dev")
	check_response "reset" "$reset_body" >/dev/null
fi

check_body=$(call_lg "$base_url/CheckDevModeSession.dev")
remaining=$(check_response "check" "$check_body")

if [[ $remaining =~ ^([0-9]+):[0-9]{2}:[0-9]{2}$ ]]; then
	hours=$((10#${BASH_REMATCH[1]}))
	echo "webos-devmode-renew: session valid ($remaining remaining)"
	if ((hours < min_hours)); then
		echo "webos-devmode-renew: remaining time ${hours}h is below threshold ${min_hours}h" >&2
		exit 1
	fi
else
	echo "webos-devmode-renew: session valid (${remaining:-no duration returned})"
fi
