# Checks a Windows release zip on a machine of the same CPU architecture.
# XerahS screen recording and the video editor rely on everything tested here.
#
#   pwsh sharex/verify-windows.ps1 ffmpeg-8.1.1-win-arm64.zip
param(
    [Parameter(Mandatory = $true)]
    [string] $Zip
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Fail([string] $Message) {
    Write-Error "FAIL: $Message"
    exit 1
}

if (-not (Test-Path -LiteralPath $Zip)) {
    Fail "zip not found: $Zip"
}

$zipFile = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Zip))
try {
    $names = @($zipFile.Entries | ForEach-Object { $_.FullName } | Sort-Object)
}
finally {
    $zipFile.Dispose()
}

$expected = @("ffmpeg.exe", "ffprobe.exe", "LICENSE.txt")
if (($names -join "|") -ne ($expected -join "|")) {
    Fail "zip must hold ffmpeg.exe, ffprobe.exe and LICENSE.txt at the root, got: $($names -join ', ')"
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("xerahs-ffmpeg-verify-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    Expand-Archive -LiteralPath $Zip -DestinationPath $work -Force
    $ffmpeg = Join-Path $work "ffmpeg.exe"
    $ffprobe = Join-Path $work "ffprobe.exe"

    function Get-PeMachine([string] $Path) {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $reader = New-Object System.IO.BinaryReader($stream)
            $stream.Position = 0x3C
            $pe = $reader.ReadInt32()
            $stream.Position = $pe + 4
            return $reader.ReadUInt16()
        }
        finally {
            $stream.Dispose()
        }
    }

    $machine = Get-PeMachine $ffmpeg
    $probeMachine = Get-PeMachine $ffprobe
    if ($machine -ne $probeMachine) {
        Fail "ffmpeg.exe machine 0x$("{0:X4}" -f $machine) does not match ffprobe.exe 0x$("{0:X4}" -f $probeMachine)"
    }

    $expectedMachine = switch ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture) {
        "X64" { 0x8664 }
        "Arm64" { 0xAA64 }
        default { 0 }
    }
    if ($machine -ne $expectedMachine) {
        Fail "this runner cannot execute machine 0x$("{0:X4}" -f $machine)"
    }

    function Assert-PerMonitorV2([string] $Path) {
        $ascii = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($Path))
        if (-not $ascii.Contains("PerMonitorV2")) {
            Fail "$(Split-Path -Leaf $Path) is missing the PerMonitorV2 manifest"
        }
    }

    Assert-PerMonitorV2 $ffmpeg
    Assert-PerMonitorV2 $ffprobe

    function Invoke-Ffmpeg([string] $File, [string[]] $Arguments) {
        $output = & $File -hide_banner @Arguments 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Fail "$([System.IO.Path]::GetFileName($File)) $($Arguments -join ' ') failed: $output"
        }
        return $output
    }

    Invoke-Ffmpeg $ffmpeg @("-version") | Select-Object -First 1 | Write-Output
    Invoke-Ffmpeg $ffprobe @("-version") | Out-Null

    function Assert-Listed([string] $Output, [string] $Name, [string] $Kind) {
        if ($Output -notmatch "(?m)^\s*\S+\s+$([regex]::Escape($Name))(\s|$)") {
            Fail "missing $Kind $Name"
        }
    }

    $encoders = Invoke-Ffmpeg $ffmpeg @("-encoders")
    foreach ($encoder in @("libx264", "libx265", "libsvtav1")) {
        Assert-Listed $encoders $encoder "encoder"
    }

    $devices = Invoke-Ffmpeg $ffmpeg @("-devices")
    foreach ($device in @("gdigrab", "dshow")) {
        Assert-Listed $devices $device "device"
    }

    $filters = Invoke-Ffmpeg $ffmpeg @("-filters")
    Assert-Listed $filters "ddagrab" "filter"

    Write-Output "OK: $([System.IO.Path]::GetFileName($Zip))"
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
