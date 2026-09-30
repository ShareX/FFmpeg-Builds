#!/bin/bash
# Checks a Linux release zip on a machine of the same CPU architecture.
# XerahS relies on everything tested here.
#
#   sharex/verify-linux.sh ffmpeg-8.1-linux-x64.zip
set -euo pipefail

ZIP="$(realpath "${1:?zip}")"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
cd "$WORK"
unzip -q "$ZIP"

fail() { echo "FAIL: $*" >&2; exit 1; }

entries="$(unzip -Z1 "$ZIP" | LC_ALL=C sort | tr '\n' ' ')"
[[ "$entries" == "LICENSE.txt ffmpeg ffprobe " ]] || fail "zip must hold ffmpeg, ffprobe and LICENSE.txt at the root, got: $entries"
[[ -x ffmpeg && -x ffprobe ]] || fail "binaries are not executable after unzip"

./ffmpeg -hide_banner -version | head -1
./ffprobe -hide_banner -version | head -1 >/dev/null

has() { grep -Eq "^ *[A-Z.]+ +$2( |$)" <<<"$1" || fail "missing $3 $2"; }

encoders="$(./ffmpeg -hide_banner -encoders)"
for encoder in libx264 libx265 libvpx-vp9 libaom-av1; do has "$encoders" "$encoder" encoder; done

devices="$(./ffmpeg -hide_banner -devices)"
for device in x11grab pulse; do has "$devices" "$device" device; done

filters="$(./ffmpeg -hide_banner -filters)"
has "$filters" drawtext filter

# One zip must run on every supported distribution: glibc 2.28 (RHEL 8) or older.
newest_glibc="$(objdump -T ffmpeg ffprobe | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)"
[[ "$(printf '%s\n' "$newest_glibc" GLIBC_2.28 | sort -V | tail -1)" == GLIBC_2.28 ]] || fail "needs $newest_glibc, above the GLIBC_2.28 floor"

echo "OK: $(basename "$ZIP") (needs ${newest_glibc})"
