#!/bin/bash
# Builds one static GPL FFmpeg for Windows and packs a flat zip the way
# ShareX/FFmpeg publishes it, including ffprobe:
#
#   ffmpeg.exe
#   ffprobe.exe
#   LICENSE.txt
#
#   sharex/build-windows.sh <win64|winarm64> <ffmpeg version, e.g. 8.1> <asset version, e.g. 8.1.1> <output dir>
#
# v8.1 is an immutable release that contains only ffmpeg.exe. A newer asset
# version (8.1.1) is how that same FFmpeg 8.1 branch is published with ffprobe.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:?target}"
VERSION="${2:?ffmpeg version}"
ASSET_VERSION="${3:?asset version}"
OUT="$(realpath -m "${4:?output dir}")"

case "$TARGET" in
    win64) RID="win-x64" ;;
    winarm64) RID="win-arm64" ;;
    *) echo "Unsupported target: $TARGET" >&2; exit 1 ;;
esac
[[ "$ASSET_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { echo "Asset version must look like 8.1 or 8.1.1" >&2; exit 1; }
[[ -f "addins/${VERSION}.sh" ]] || { echo "No addin for FFmpeg ${VERSION}" >&2; exit 1; }

# Toolchain and dependency images come from upstream BtbN. Pull once and
# record the digest so the release notes say exactly which image built it.
IMAGE="ghcr.io/btbn/ffmpeg-builds/${TARGET}-gpl-${VERSION}:latest"
docker pull "$IMAGE"
IMAGE_DIGEST="$(docker image inspect --format '{{index .RepoDigests 0}}' "$IMAGE")"

rm -rf artifacts
# build.sh derives the image name from GITHUB_REPOSITORY; point it at the
# image pulled above. FFmpeg itself is cloned from the release/<version> branch.
# ffprobe is part of that build. The published v8.1 zip dropped it at pack time.
GITHUB_REPOSITORY=btbn/ffmpeg-builds ./build.sh "$TARGET" gpl "$VERSION"

ZIP_SRC="$(ls artifacts/*.zip)"
STAGE="$(mktemp -d)"
FLAT="$(mktemp -d)"
trap 'rm -rf -- "$STAGE" "$FLAT"' EXIT
unzip -q "$ZIP_SRC" -d "$STAGE"

FFMPEG="$(find "$STAGE" -type f -name ffmpeg.exe -print -quit)"
FFPROBE="$(find "$STAGE" -type f -name ffprobe.exe -print -quit)"
LICENSE="$(find "$STAGE" -type f -name LICENSE.txt -print -quit)"
if [[ -z "$FFMPEG" || -z "$FFPROBE" || -z "$LICENSE" ]]; then
    echo "Build did not produce ffmpeg.exe, ffprobe.exe and LICENSE.txt" >&2
    find "$STAGE" -type f -print >&2
    exit 1
fi

cp "$FFMPEG" "$FFPROBE" "$LICENSE" "$FLAT/"

mkdir -p "$OUT"
ZIP="$OUT/ffmpeg-${ASSET_VERSION}-${RID}.zip"
rm -f "$ZIP"
(cd "$FLAT" && zip -9 -X "$ZIP" ffmpeg.exe ffprobe.exe LICENSE.txt)

BUILD_NAME="$(basename "$ZIP_SRC" .zip)"
cat > "$OUT/build-info-${RID}.txt" <<EOF
asset: $(basename "$ZIP")
ffmpeg: ${BUILD_NAME}
ffmpeg-branch: release/${VERSION}
builds-commit: $(git rev-parse HEAD)
image: ${IMAGE_DIGEST}
EOF
cat "$OUT/build-info-${RID}.txt"
rm -rf artifacts
