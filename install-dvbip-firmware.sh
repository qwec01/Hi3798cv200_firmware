#!/usr/bin/env bash
# Install the public Hi3798CV200 runtime files from this firmware directory.
set -Eeuo pipefail

umask 022

readonly DEFAULT_BASE_URL="https://raw.githubusercontent.com/DVBIP-Development/DVB-IP/main/DVBIP-Development/firmware"
BASE_URL="${DVBIP_FIRMWARE_BASE_URL:-$DEFAULT_BASE_URL}"
FORCE_CONFIG=0

usage() {
	cat <<'EOF'
Usage: install-dvbip-firmware.sh [--force-config]

Downloads and installs the public Hi3798CV200 runtime files, firmware and
OSCam systemd unit. Existing OSCam configuration is preserved by default.
Set DVBIP_FIRMWARE_BASE_URL to use another published branch or mirror.
EOF
}

die() {
	echo "install-dvbip-firmware: $*" >&2
	exit 1
}

warn() {
	echo "install-dvbip-firmware: warning: $*" >&2
}

for arg in "$@"; do
	case "$arg" in
		--force-config)
			FORCE_CONFIG=1
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage >&2
			die "unknown option: $arg"
			;;
	esac
done

if [[ "$(id -u)" -ne 0 ]]; then
	command -v sudo >/dev/null 2>&1 || die "run as root or install sudo"
	exec sudo -E env "DVBIP_FIRMWARE_BASE_URL=$BASE_URL" bash "$0" "$@"
fi

[[ "$(uname -m)" == "aarch64" ]] || die "this runtime is for AArch64; found $(uname -m)"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"
command -v install >/dev/null 2>&1 || die "install is required"
command -v mktemp >/dev/null 2>&1 || die "mktemp is required"
command -v apt-get >/dev/null 2>&1 || die "apt-get is required"
command -v systemctl >/dev/null 2>&1 || die "systemctl is required"

if command -v curl >/dev/null 2>&1; then
	DOWNLOAD_TOOL=curl
elif command -v wget >/dev/null 2>&1; then
	DOWNLOAD_TOOL=wget
else
	die "curl or wget is required to download the runtime files"
fi

echo "Installing Debian runtime dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates ffmpeg libc6 libdrm2 libudev1

BASE_URL="${BASE_URL%/}"
STAGE=$(mktemp -d -t dvbip-firmware.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT

declare -a REQUIRED_FILES=(
	"hivxe-ffmpeg-9.0.1"
	"hivxe-top"
	"oscam/oscam"
	"oscam/config/oscam.conf"
	"oscam/config/oscam.dvbapi"
	"oscam/config/oscam.server"
	"oscam/config/oscam.user"
	"oscam/config/oscam.service"
	"hisilicon/histb-avsp.bin"
	"hisilicon/histb-h264-cabac.bin"
	"hisilicon/histb-hevc-cabac.bin"
	"mxl214/mxl214.fw"
	"mxl214/nvram50.bin"
)

declare -A EXPECTED_SHA256=(
	["hivxe-ffmpeg-9.0.1"]="9f0b6f6fac09eddd46ecc87983313f44916dfaef5da47cac576f9896b2653876"
	["hivxe-top"]="27c8a7cd8b19f5232315a20da8d8856478025e701c2a17156d8bd0f9fb865954"
	["oscam/oscam"]="b6c03197a392c333300da7f0ea22e43b64a910d75d0e48db49a56da4dab9b574"
	["oscam/config/oscam.conf"]="81b01251fb7120f22930a3fa80a40f245fc703fdab54e97693557242c0763daa"
	["oscam/config/oscam.dvbapi"]="fc78f318dfcccfa3770884122d4299b1245fb8563a62ff8764b66b857abc920e"
	["oscam/config/oscam.server"]="6ff55037a9e3d5ed05c9d5841a629d78be3a80816bc930d3af2e4a75c580f5ed"
	["oscam/config/oscam.user"]="57032a1058db97af7b991cbc37d813027fca635cad6c36ee384adb5f172ec8f8"
	["oscam/config/oscam.service"]="92dbc045aec79f3e2d21f24fa79c8e46bbd5924a9f84fa071894e4fef3b700b2"
	["hisilicon/histb-avsp.bin"]="4ec0ea0b21ebd45057bbad20a1b69893fc02a4ae6244f46503781141fc785d3f"
	["hisilicon/histb-h264-cabac.bin"]="0f5b1a41f7d2ab21f1bd5ffc7be9a3e4777cac1c81cc15f53cc6cd12998a626e"
	["hisilicon/histb-hevc-cabac.bin"]="eb04288c3fa644565f9d71931918cf27f02022ffb77b4343383b80d2dcfff972"
	["mxl214/mxl214.fw"]="c3db0520fdb41f8e2fe52499a9b770c7ad2c5d2fc89ae841a6c13fcb3f757916"
	["mxl214/nvram50.bin"]="a7e1515ead87e98c68efb5c0ce5c9509af45965421cc37433794cc2a0f48c589"
)

download_file() {
	local relative="$1"
	local destination="$STAGE/$relative"
	local parent
	parent=$(dirname "$destination")
	mkdir -p "$parent"
	echo "Downloading $relative"
	if [[ "$DOWNLOAD_TOOL" == curl ]]; then
		curl --fail --location --retry 3 --silent --show-error \
			"$BASE_URL/$relative" -o "$destination"
	else
		wget --https-only --quiet --tries=3 \
			-O "$destination" "$BASE_URL/$relative"
	fi
	[[ -s "$destination" ]] || die "downloaded file is empty: $relative"
}

for relative in "${REQUIRED_FILES[@]}"; do
	download_file "$relative"
done

for relative in "${!EXPECTED_SHA256[@]}"; do
	actual=$(sha256sum "$STAGE/$relative" | awk '{print $1}')
	if [[ "$actual" != "${EXPECTED_SHA256[$relative]}" ]]; then
		die "SHA-256 mismatch for $relative (got $actual)"
	fi
done

install_config() {
	local source="$1"
	local destination="$2"
	if [[ -e "$destination" && "$FORCE_CONFIG" -ne 1 ]]; then
		echo "Preserving existing OSCam configuration: $destination"
		return 0
	fi
	install -D -m 0644 "$source" "$destination"
}

echo "Installing HiVXE tools..."
install -D -m 0755 "$STAGE/hivxe-ffmpeg-9.0.1" \
	/usr/local/bin/hivxe-ffmpeg
install -D -m 0755 "$STAGE/hivxe-top" /usr/local/bin/hivxe-top

echo "Installing HiSilicon decoder firmware..."
install -D -m 0644 "$STAGE/hisilicon/histb-avsp.bin" \
	/usr/lib/firmware/hisilicon/histb-avsp.bin
install -D -m 0644 "$STAGE/hisilicon/histb-h264-cabac.bin" \
	/usr/lib/firmware/hisilicon/histb-h264-cabac.bin
install -D -m 0644 "$STAGE/hisilicon/histb-hevc-cabac.bin" \
	/usr/lib/firmware/hisilicon/histb-hevc-cabac.bin

echo "Installing MxL214 firmware..."
install -D -m 0644 "$STAGE/mxl214/mxl214.fw" \
	/usr/lib/firmware/mxl214/mxl214.fw
install -D -m 0644 "$STAGE/mxl214/nvram50.bin" \
	/usr/lib/firmware/mxl214/nvram50.bin

echo "Installing OSCam..."
install -D -m 0755 "$STAGE/oscam/oscam" /usr/local/bin/oscam
install_config "$STAGE/oscam/config/oscam.conf" /usr/local/etc/oscam.conf
install_config "$STAGE/oscam/config/oscam.dvbapi" /usr/local/etc/oscam.dvbapi
install_config "$STAGE/oscam/config/oscam.server" /usr/local/etc/oscam.server
install_config "$STAGE/oscam/config/oscam.user" /usr/local/etc/oscam.user
install -D -m 0644 "$STAGE/oscam/config/oscam.service" \
	/etc/systemd/system/oscam.service

systemctl daemon-reload
systemctl enable --now oscam.service

echo
echo "DVBIP runtime installation completed."
echo "OSCam: $(systemctl is-active oscam.service 2>/dev/null || true)"
echo "DVB devices:"
ls -d /dev/dvb/adapter* 2>/dev/null || echo "  no DVB adapter is currently enumerated"
echo "Firmware log (if a driver has already requested it):"
dmesg | grep -E 'histb|mxl214|firmware' | tail -n 20 || true
