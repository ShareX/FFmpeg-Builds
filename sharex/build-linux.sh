#!/bin/bash
# Builds one static GPL FFmpeg for Linux and packs it the way ShareX/FFmpeg
# publishes Windows builds: ffmpeg-<version>-<rid>.zip, flat, no folders.
#
#   sharex/build-linux.sh <linux64|linuxarm64> <ffmpeg version, e.g. 8.1> <output dir>
#
# The Windows builds are made separately and are not touched by this script.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:?target}"
VERSION="${2:?version}"
OUT="$(realpath -m "${3:?output dir}")"

case "$TARGET" in
    linux64) RID="linux-x64" ;;
    linuxarm64) RID="linux-arm64" ;;
    *) echo "Unsupported target: $TARGET" >&2; exit 1 ;;
esac
[[ -f "addins/${VERSION}.sh" ]] || { echo "No addin for FFmpeg ${VERSION}" >&2; exit 1; }

# The toolchain and dependency images come from upstream BtbN. Pull once and
# record the digest, so the release notes say exactly which image built it.
IMAGE="ghcr.io/btbn/ffmpeg-builds/${TARGET}-gpl-${VERSION}:latest"
docker pull "$IMAGE"
IMAGE_DIGEST="$(docker image inspect --format '{{index .RepoDigests 0}}' "$IMAGE")"

rm -rf artifacts
# build.sh derives the image name from GITHUB_REPOSITORY; point it at the
# image pulled above. FFmpeg itself is cloned from the release/<version> branch.
GITHUB_REPOSITORY=btbn/ffmpeg-builds ./build.sh "$TARGET" gpl "$VERSION"

TARBALL="$(ls artifacts/*.tar.xz)"
STAGE="$(mktemp -d)"
trap 'rm -rf -- "$STAGE"' EXIT
# <build>/bin/ffmpeg -> ffmpeg. ffprobe is required: the XerahS video editor uses it.
tar -xJf "$TARBALL" -C "$STAGE" --strip-components=2 --wildcards '*/bin/ffmpeg' '*/bin/ffprobe'
tar -xJf "$TARBALL" -C "$STAGE" --strip-components=1 --wildcards '*/LICENSE.txt'
chmod 755 "$STAGE/ffmpeg" "$STAGE/ffprobe"

mkdir -p "$OUT"
ZIP="$OUT/ffmpeg-${VERSION}-${RID}.zip"
rm -f "$ZIP"
(cd "$STAGE" && zip -9 -X "$ZIP" ffmpeg ffprobe LICENSE.txt)

BUILD_NAME="$(basename "$TARBALL" .tar.xz)"
cat > "$OUT/build-info-${RID}.txt" <<EOF
asset: $(basename "$ZIP")
ffmpeg: ${BUILD_NAME}
ffmpeg-branch: release/${VERSION}
builds-commit: $(git rev-parse HEAD)
image: ${IMAGE_DIGEST}
EOF
cat "$OUT/build-info-${RID}.txt"
rm -rf artifacts
