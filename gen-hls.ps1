<#
.SYNOPSIS
Builds an adaptive HLS ladder from MP4 source files using ffmpeg.

.DESCRIPTION
This is a skeleton script meant to fit the site's existing Windows-first media workflow.
It scans post folders for MP4 files, then creates HLS outputs in a "stream/" subfolder
with a master playlist and one playlist per rendition.

Expected output layout for each source clip:
  assets/img/posts/<post-folder>/stream/<clip-name>/master.m3u8
  assets/img/posts/<post-folder>/stream/<clip-name>/360p/index.m3u8
  assets/img/posts/<post-folder>/stream/<clip-name>/360p/seg_000.ts
  assets/img/posts/<post-folder>/stream/<clip-name>/720p/index.m3u8
  assets/img/posts/<post-folder>/stream/<clip-name>/1080p/index.m3u8
#>

[CmdletBinding()]
param(
    [string]$PostsRoot = "./assets/img/posts",
    [string[]]$TargetPosts,
    [switch]$Rebuild,
    [switch]$WhatIf,
    [ValidateRange(1, 200)]
    [int]$PosterScale = 100,
    [ValidateRange(0, 100)]
    [int]$PosterQuality = 75
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-RequiredTooling
{
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue))
    {
        throw "ffmpeg was not found in PATH. Install ffmpeg and retry."
    }

    if (-not (Get-Command magick -ErrorAction SilentlyContinue))
    {
        throw "ImageMagick 'magick' was not found in PATH. Install ImageMagick and retry."
    }
}

function New-VideoPoster
{
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$Clip
    )

    $thumbDir = Join-Path $Clip.Directory.FullName "thumbnails"
    if (-not (Test-Path $thumbDir))
    {
        New-Item -ItemType Directory -Path $thumbDir -Force | Out-Null
    }

    $posterPath = Join-Path $thumbDir ("{0}.avif" -f $Clip.BaseName)

    $needsPoster = $true
    if (Test-Path $posterPath)
    {
        try
        {
            $sourceInfo = Get-Item -LiteralPath $Clip.FullName
            $destInfo = Get-Item -LiteralPath $posterPath
            if (-not $Rebuild -and $sourceInfo.LastWriteTimeUtc -le $destInfo.LastWriteTimeUtc)
            {
                $needsPoster = $false
            }
        }
        catch
        {
            Write-Warning "Failed to compare timestamps for poster '$posterPath'. Regenerating."
        }
    }

    if (-not $needsPoster)
    {
        return
    }

    $resizePercent = if ($PosterScale -ne 100) { "{0}%" -f $PosterScale } else { $null }

    $inputArg = "{0}[0]" -f $Clip.FullName
    $args = @()
    $args += $inputArg
    if ($resizePercent)
    {
        $args += "-resize"
        $args += $resizePercent
    }
    $args += "-strip"
    $args += "-quality"
    $args += $PosterQuality.ToString()
    $args += $posterPath

    if ($WhatIf)
    {
        Write-Host "[WhatIf] magick $($args -join ' ')"
        return
    }

    Write-Host "Generating poster frame: $posterPath"
    & magick @args
    if ($LASTEXITCODE -ne 0)
    {
        throw "magick failed while generating poster for clip $($Clip.FullName)"
    }
}

function Get-Renditions
{
    @(
        @{
            Name         = "360p"
            Width        = 640
            Height       = 360
            VideoBitrate = "800k"
            MaxRate      = "900k"
            BufferSize   = "1200k"
            AudioBitrate = "96k"
            Bandwidth    = 900000
        }
        @{
            Name         = "720p"
            Width        = 1280
            Height       = 720
            VideoBitrate = "2800k"
            MaxRate      = "3200k"
            BufferSize   = "5600k"
            AudioBitrate = "128k"
            Bandwidth    = 3200000
        }
        @{
            Name         = "1080p"
            Width        = 1920
            Height       = 1080
            VideoBitrate = "5000k"
            MaxRate      = "5500k"
            BufferSize   = "10000k"
            AudioBitrate = "192k"
            Bandwidth    = 5500000
        }
    )
}

function New-HlsVariant
{
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][hashtable]$Rendition
    )

    $variantDir = Join-Path $OutputDir $Rendition.Name
    New-Item -ItemType Directory -Path $variantDir -Force | Out-Null

    $playlistPath = Join-Path $variantDir "index.m3u8"
    $segmentPattern = Join-Path $variantDir "seg_%03d.ts"

    $args = @(
        "-y",
        "-i", $InputFile,
        "-vf", "scale=w=$($Rendition.Width):h=$($Rendition.Height):force_original_aspect_ratio=decrease,pad=$($Rendition.Width):$($Rendition.Height):(ow-iw)/2:(oh-ih)/2",
        "-c:v", "libx264",
        "-profile:v", "high",
        "-preset", "medium",
        "-g", "48",
        "-keyint_min", "48",
        "-sc_threshold", "0",
        "-b:v", $Rendition.VideoBitrate,
        "-maxrate", $Rendition.MaxRate,
        "-bufsize", $Rendition.BufferSize,
        "-c:a", "aac",
        "-b:a", $Rendition.AudioBitrate,
        "-ac", "2",
        "-ar", "48000",
        "-f", "hls",
        "-hls_time", "4",
        "-hls_playlist_type", "vod",
        "-hls_flags", "independent_segments",
        "-hls_segment_filename", $segmentPattern,
        $playlistPath
    )

    if ($WhatIf)
    {
        Write-Host "[WhatIf] ffmpeg $($args -join ' ')"
        return
    }

    Write-Host "Encoding $($Rendition.Name) from $InputFile"
    & ffmpeg @args
    if ($LASTEXITCODE -ne 0)
    {
        throw "ffmpeg failed for rendition $($Rendition.Name): $InputFile"
    }
}

function New-MasterPlaylist
{
    param(
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][array]$Renditions
    )

    $masterPath = Join-Path $OutputDir "master.m3u8"
    $lines = @("#EXTM3U", "#EXT-X-VERSION:3")

    foreach ($rendition in $Renditions)
    {
        $lines += "#EXT-X-STREAM-INF:BANDWIDTH=$($rendition.Bandwidth),RESOLUTION=$($rendition.Width)x$($rendition.Height)"
        $lines += "$($rendition.Name)/index.m3u8"
    }

    Set-Content -Path $masterPath -Value $lines -Encoding UTF8
}

function Convert-ClipToHls
{
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$Clip
    )

    New-VideoPoster -Clip $Clip

    $streamRoot = Join-Path $Clip.Directory.FullName "stream"
    $outputDir = Join-Path $streamRoot $Clip.BaseName

    if ((Test-Path $outputDir) -and -not $Rebuild)
    {
        Write-Host "Skipping existing HLS output: $outputDir"
        return
    }

    if (Test-Path $outputDir)
    {
        Remove-Item -Path $outputDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    $renditions = Get-Renditions

    foreach ($rendition in $renditions)
    {
        New-HlsVariant -InputFile $Clip.FullName -OutputDir $outputDir -Rendition $rendition
    }

    New-MasterPlaylist -OutputDir $outputDir -Renditions $renditions
    Write-Host "Created HLS set: $outputDir"
}

Test-RequiredTooling

$root = Resolve-Path $PostsRoot
$postDirs = if ($TargetPosts -and $TargetPosts.Count -gt 0)
{
    $TargetPosts | ForEach-Object { Join-Path $root $_ }
}
else
{
    Get-ChildItem -Path $root -Directory | Select-Object -ExpandProperty FullName
}

foreach ($postDir in $postDirs)
{
    if (-not (Test-Path $postDir))
    {
        Write-Warning "Post folder not found: $postDir"
        continue
    }

    $clips = @()
    $clips += Get-ChildItem -Path $postDir -Filter "*.mp4" -File -ErrorAction SilentlyContinue
    $clips += Get-ChildItem -Path $postDir -Filter "*.mov" -File -ErrorAction SilentlyContinue

    foreach ($clip in $clips)
    {
        Convert-ClipToHls -Clip $clip
    }
}

Write-Host "Done."
