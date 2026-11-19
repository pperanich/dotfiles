#!/usr/bin/env bash
set -euo pipefail
umask 077

# Pinned RustDesk release and official x86_64 package SHA-256 digests.
DEFAULT_RUSTDESK_VERSION="1.5.1"
PINNED_DEB_SHA256="b5d682ad90cb7571ecbdbf26eef58d3c4514e726a74ef6d08ce3f0b114ef0bd9"
PINNED_RPM_SHA256="089b95378e8e9a064d71577293d3eb04784f087e8213204da4d5464bcb9e0807"

RUSTDESK_VERSION="${RUSTDESK_VERSION:-$DEFAULT_RUSTDESK_VERSION}"
RUSTDESK_SHA256="${RUSTDESK_SHA256:-}"
TEMP_DIR=""

cleanup() {
	if [[ -n ${TEMP_DIR:-} && -d $TEMP_DIR ]]; then
		rm -rf "$TEMP_DIR"
	fi
}
trap cleanup EXIT INT TERM

usage() {
	echo "Usage: $(basename "$0") [--version <ver> --sha256 <sha256>]" >&2
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--version)
		[[ $# -ge 2 ]] || usage
		RUSTDESK_VERSION="$2"
		shift 2
		;;
	--sha256)
		[[ $# -ge 2 ]] || usage
		RUSTDESK_SHA256="$2"
		shift 2
		;;
	-h | --help)
		usage
		;;
	*)
		echo "ERROR: Unknown argument: $1" >&2
		usage
		;;
	esac
done

if [[ ! $RUSTDESK_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)*$ ]]; then
	echo "ERROR: Invalid RustDesk version: $RUSTDESK_VERSION" >&2
	exit 1
fi

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root." >&2
	exit 1
fi

# Generate a strong 24-character alphanumeric password without SIGPIPE under pipefail.
rustdesk_pw=$(LC_ALL=C head -c 512 /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c 24)
if [[ ${#rustdesk_pw} -ne 24 ]]; then
	echo "ERROR: Failed to generate random RustDesk password." >&2
	exit 1
fi

verify_sha256() {
	local file="$1"
	local expected="${2,,}"
	local actual=""

	if [[ ! $expected =~ ^[0-9a-f]{64}$ ]]; then
		echo "ERROR: Expected SHA-256 digest must be 64 hex characters." >&2
		exit 1
	fi

	if command -v sha256sum >/dev/null 2>&1; then
		actual=$(sha256sum "$file" | awk '{print tolower($1)}')
	elif command -v shasum >/dev/null 2>&1; then
		actual=$(shasum -a 256 "$file" | awk '{print tolower($1)}')
	else
		echo "ERROR: Neither sha256sum nor shasum is installed to verify package integrity." >&2
		exit 1
	fi

	if [[ $actual != "$expected" ]]; then
		echo "ERROR: SHA-256 mismatch for $(basename "$file"): expected $expected, got $actual" >&2
		exit 1
	fi
}

# Identify OS
ID=""
UPSTREAM_ID=""
if [[ -f /etc/os-release ]]; then
	# shellcheck disable=SC1091 # provided by the target distro
	. /etc/os-release
	OS="${NAME:-}"
	UPSTREAM_ID="${ID_LIKE:-}"
	UPSTREAM_ID="${UPSTREAM_ID,,}"
	if [[ $UPSTREAM_ID != "debian" && $UPSTREAM_ID != "ubuntu" ]]; then
		UPSTREAM_ID=$(echo "$UPSTREAM_ID" | tr -d '"' | cut -d' ' -f1)
	fi
elif command -v lsb_release >/dev/null 2>&1; then
	OS=$(lsb_release -si)
elif [[ -f /etc/lsb-release ]]; then
	# shellcheck disable=SC1091 # provided by the target distro
	. /etc/lsb-release
	OS="${DISTRIB_ID:-}"
elif [[ -f /etc/debian_version ]]; then
	OS="Debian"
elif [[ -f /etc/SuSE-release ]]; then
	OS="SuSE"
elif [[ -f /etc/redhat-release ]]; then
	OS="RedHat"
else
	OS=$(uname -s)
fi

pkg_kind=""
pkg_file=""
default_sha256=""

if [[ $ID == "debian" || $ID == "ubuntu" || $OS == "Ubuntu" || $OS == "Debian" || $UPSTREAM_ID == "ubuntu" || $UPSTREAM_ID == "debian" ]]; then
	pkg_kind="deb"
	pkg_file="rustdesk-${RUSTDESK_VERSION}-x86_64.deb"
	default_sha256="$PINNED_DEB_SHA256"
elif [[ $OS == "CentOS" || $OS == "RedHat" || $OS == "Fedora Linux" || $UPSTREAM_ID == "rhel" || $UPSTREAM_ID == "fedora" || $OS == "Almalinux" || $OS == Rocky* ]]; then
	pkg_kind="rpm"
	pkg_file="rustdesk-${RUSTDESK_VERSION}-0.x86_64.rpm"
	default_sha256="$PINNED_RPM_SHA256"
else
	echo "Unsupported OS: ${OS}" >&2
	exit 1
fi

expected_sha256="$RUSTDESK_SHA256"
if [[ -z $expected_sha256 ]]; then
	if [[ $RUSTDESK_VERSION == "$DEFAULT_RUSTDESK_VERSION" ]]; then
		expected_sha256="$default_sha256"
	else
		echo "ERROR: --sha256 (or RUSTDESK_SHA256) is required when overriding --version (${RUSTDESK_VERSION})." >&2
		exit 1
	fi
fi

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rustdesk-install.XXXXXX")
pkg_path="${TEMP_DIR}/${pkg_file}"
pkg_url="https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}/${pkg_file}"

echo "Downloading RustDesk ${RUSTDESK_VERSION} (${pkg_file})..."
curl -fsSL --proto '=https' --tlsv1.2 -o "$pkg_path" "$pkg_url"
verify_sha256 "$pkg_path" "$expected_sha256"

echo "Installing verified RustDesk package..."
if [[ $pkg_kind == "deb" ]]; then
	apt-get install -fy "$pkg_path" >/dev/null
else
	yum localinstall "$pkg_path" -y >/dev/null
fi

rustdesk --password "$rustdesk_pw" &>/dev/null
systemctl restart rustdesk
sleep 2
rustdesk_id=$(rustdesk --get-id 2>/dev/null) || rustdesk_id=""

echo "..............................................."
if [[ -n $rustdesk_id ]]; then
	echo "RustDesk ID: $rustdesk_id"
else
	echo "Failed to get RustDesk ID."
fi
echo "Password: $rustdesk_pw"
echo "..............................................."
