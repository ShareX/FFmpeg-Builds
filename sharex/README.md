# ShareX release packaging

This `linux` branch is upstream [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) plus this folder. It builds the FFmpeg zips that XerahS downloads. `master` is the older Windows fork: it still passes `--disable-ffprobe` and zips `ffmpeg.exe` alone, and its workflow stays disabled.

| Script | What it does |
|---|---|
| `build-linux.sh <linux64\|linuxarm64> <version> <out>` | Builds static GPL FFmpeg from the `release/<version>` branch and writes `ffmpeg-<version>-linux-x64.zip` or `ffmpeg-<version>-linux-arm64.zip`, plus `build-info-<rid>.txt`. |
| `verify-linux.sh <zip>` | Checks the zip on a machine of the same CPU: layout, `libx264`/`libx265`/`libvpx-vp9`/`libaom-av1`, `x11grab`/`pulse`, `drawtext`, and the glibc 2.28 floor. |
| `build-windows.sh <win64\|winarm64> <version> <asset version> <out>` | Builds the same FFmpeg branch and writes `ffmpeg-<asset version>-win-x64.zip` or `ffmpeg-<asset version>-win-arm64.zip` with `ffprobe.exe` included. |
| `verify-windows.ps1 <zip>` | Checks the zip on a machine of the same CPU: layout, `libx264`/`libx265`/`libsvtav1`, `gdigrab`/`dshow`, `ddagrab`, and the PerMonitorV2 manifest. |

A Linux zip holds `ffmpeg`, `ffprobe` and `LICENSE.txt` at the root. A Windows zip holds `ffmpeg.exe`, `ffprobe.exe` and `LICENSE.txt`.

Linux releases are made by `.github/workflows/linux-release.yml` in [ShareX/FFmpeg](https://github.com/ShareX/FFmpeg). That release is `v<version>-linux` and is never marked latest. Windows releases are made by `.github/workflows/windows-release.yml`. `v8.1` stays as published (ffmpeg only). A newer tag, `v8.1.1` by default, is marked latest and is the one that contains ffprobe.

The upstream workflows are removed on this branch so nothing here builds or pushes images by itself. To update from upstream:

```bash
git fetch https://github.com/BtbN/FFmpeg-Builds.git master
git merge FETCH_HEAD   # keep the deletions under .github/workflows
```
