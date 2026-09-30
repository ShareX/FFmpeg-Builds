# ShareX Linux builds

This `linux` branch is upstream [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) plus this folder. It exists only to make the Linux FFmpeg that XerahS downloads. The Windows builds on `master` and their release process are separate and unchanged.

| Script | What it does |
|---|---|
| `build-linux.sh <linux64\|linuxarm64> <version> <out>` | Builds static GPL FFmpeg from the `release/<version>` branch and writes `ffmpeg-<version>-linux-x64.zip` or `ffmpeg-<version>-linux-arm64.zip`, plus `build-info-<rid>.txt`. |
| `verify-linux.sh <zip>` | Checks the zip on a machine of the same CPU: layout, `libx264`/`libx265`/`libvpx-vp9`/`libaom-av1`, `x11grab`/`pulse`, `drawtext`, and the glibc 2.28 floor. |

The zip holds `ffmpeg`, `ffprobe` and `LICENSE.txt` at the root, the same flat layout and `ffmpeg-<version>-<rid>.zip` naming as the Windows zips.

Releases are made by `.github/workflows/linux-release.yml` in [ShareX/FFmpeg](https://github.com/ShareX/FFmpeg), which checks out this branch, builds both architectures, runs the checks on native x64 and arm64 runners, signs `SHA256SUMS` and publishes a `v<version>-linux` release that is never marked latest.

The upstream workflows are removed on this branch so nothing here builds or pushes images by itself. To update from upstream:

```bash
git fetch https://github.com/BtbN/FFmpeg-Builds.git master
git merge FETCH_HEAD   # keep the deletions under .github/workflows
```
