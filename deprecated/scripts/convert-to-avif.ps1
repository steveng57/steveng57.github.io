<#
WARNING: Deprecated script. Kept for historical reference only.
Use `gen-derived-avif.ps1` in the repository root for AVIF derivative generation.
#>
<#
.SYNOPSIS
    Converts site images to AVIF while preserving original JPEG files and metadata.

.DESCRIPTION
    Recursively scans the provided image root, converts supported source files to AVIF using avifenc,
    and stores the output alongside the originals. Existing JPEG/PNG assets are retained. Re-encoding
    occurs when the source image is newer than the existing AVIF or when -Force is specified.

.PARAMETER SourcePath
    Root folder that contains the post media directories. Defaults to .\assets\img\posts.

.PARAMETER Quality
    AVIF encoder quality value (0-100, higher is better). Defaults to 75.

.PARAMETER Speed
    Encoder speed preset (0-10, lower is higher quality but slower). Defaults to 6.

.PARAMETER Jobs
    Number of worker threads to hand to avifenc ("all" uses every available core). Defaults to "all".

.PARAMETER Force
    Rebuild AVIF files even when the existing AVIF is newer than the source image.

.PARAMETER SkipDerived
    Skip derived directories such as thumbnails/ and tinyfiles/. By default the script processes
    every subdirectory under the source path.

.EXAMPLE
    .\convert-to-avif.ps1 -SourcePath .\assets\img\posts -Quality 80 -Speed 4

.EXAMPLE
    .\convert-to-avif.ps1 -SkipDerived
    Converts only the original assets and ignores thumbnails/ and tinyfiles/ derivatives.
#>
param(
    [string]$SourcePath = ".\assets\img\posts",
    [ValidateRange(0,100)]
    [int]$Quality = 75,
    [ValidateRange(0,10)]
    [int]$Speed = 6,
    [Parameter()]
    [ValidatePattern("^([Aa][Ll][Ll]|\d+)$")]
    [string]$Jobs = "all",
    [switch]$Force,
    [switch]$SkipDerived
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[AVIF] $Message" -ForegroundColor Cyan
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[AVIF] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[AVIF] $Message" -ForegroundColor Red
}

try {
    $avifenc = Get-Command "avifenc" -ErrorAction Stop
} catch {
    Write-ErrorMessage "avifenc not found. Install libavif tools and ensure avifenc is on PATH."
    exit 1
}

if (-not (Test-Path -Path $SourcePath)) {
    Write-ErrorMessage "Source path '$SourcePath' was not found."
    exit 1
}

$resolvedSource = Resolve-Path -Path $SourcePath
Write-Info "Scanning '$resolvedSource' for images to convert."

$extensions = @('.jpeg', '.jpg', '.png')
$images = Get-ChildItem -Path $resolvedSource -Recurse -File |
    Where-Object {
        $extensions -contains $_.Extension.ToLower() -and
        (
            -not $SkipDerived -or (
                $_.DirectoryName -notmatch "[\\/]thumbnails([\\/]|$)" -and
                $_.DirectoryName -notmatch "[\\/]tinyfiles([\\/]|$)"
            )
        )
    }

if (-not $images) {
    Write-Info "No eligible source images found."
    exit 0
}

$converted = 0
$skipped = 0
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($image in $images) {
    $destination = [System.IO.Path]::ChangeExtension($image.FullName, ".avif")

    if (Test-Path -LiteralPath $destination) {
        $destInfo = Get-Item -LiteralPath $destination
        if (-not $Force -and $destInfo.LastWriteTimeUtc -ge $image.LastWriteTimeUtc) {
            $skipped++
            continue
        }
    }

    $arguments = @(
        "-q", $Quality.ToString(),
        "-s", $Speed.ToString(),
        "--jobs", $Jobs,
        $image.FullName,
        $destination
    )

    try {
        Write-Info "Encoding '$($image.FullName)' -> '$destination'"
        & $avifenc.Source $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "avifenc exited with code $LASTEXITCODE"
        }
        $converted++
    } catch {
        Write-WarningMessage "Failed to encode '$($image.FullName)': $_"
    }
}

$stopwatch.Stop()
Write-Info "Conversion complete: $converted converted, $skipped skipped in $($stopwatch.Elapsed.ToString())."
exit 0
