<#
.SYNOPSIS
Builds an adaptive HLS ladder from MP4 source files using ffmpeg.

.DESCRIPTION
This is a skeleton script meant to fit the site's existing Windows-first media workflow.
It scans post folders for MP4 files, then creates HLS outputs in a "stream/" subfolder
with a master playlist and one playlist per rendition.

Expected output layout for each source clip:
  assets/img/posts/<post-folder>/stream/<clip-name>/master.m3u8
  assets/img/posts/<post-folder>/stream/<clip-name>/poster.avif
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

    if (-not (Get-Command exiftool -ErrorAction SilentlyContinue))
    {
        throw "ExifTool was not found in PATH. Install ExifTool and retry."
    }
}

function Copy-Metadata
{
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    $args = @(
        "-overwrite_original",
        "-TagsFromFile",
        $SourcePath,
        "-Title",
        "-ImageDescription",
        "-Description",
        "-XPTitle",
        "-XPSubject",
        "-Subject",
        "-Keywords",
        "-HierarchicalSubject",
        "-DateTimeOriginal",
        "-CreateDate",
        $DestinationPath
    )

    $previousLcAll = $env:LC_ALL
    $previousLang = $env:LANG
    try
    {
        $env:LC_ALL = "C"
        $env:LANG = "C"
        & exiftool @args
        if ($LASTEXITCODE -ne 0)
        {
            throw "exiftool failed while copying metadata to $DestinationPath"
        }
    }
    finally
    {
        $env:LC_ALL = $previousLcAll
        $env:LANG = $previousLang
    }
}

function Get-MetadataSnapshot
{
    param([Parameter(Mandatory = $true)][string]$Path)

    $args = @(
        "-json",
        "-Title",
        "-ImageDescription",
        "-Description",
        "-XPTitle",
        "-XPSubject",
        "-Subject",
        "-Keywords",
        "-HierarchicalSubject",
        "-DateTimeOriginal",
        "-CreateDate",
        $Path
    )

    $previousLcAll = $env:LC_ALL
    $previousLang = $env:LANG
    try
    {
        $env:LC_ALL = "C"
        $env:LANG = "C"
        $json = & exiftool @args
        if ($LASTEXITCODE -ne 0)
        {
            throw "exiftool failed while reading metadata from $Path"
        }

        $items = $json | ConvertFrom-Json
        return $items | Select-Object -First 1
    }
    finally
    {
        $env:LC_ALL = $previousLcAll
        $env:LANG = $previousLang
    }
}

function Convert-MetadataValue
{
    param($Value)

    if ($null -eq $Value)
    {
        return ""
    }

    $values = if ($Value -is [array]) { @($Value) } else { @($Value) }
    return ($values |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.ToString().Trim() } |
        Sort-Object) -join "`n"
}

function Test-MetadataCopyNeeded
{
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $DestinationPath))
    {
        return $true
    }

    $sourceMetadata = Get-MetadataSnapshot -Path $SourcePath
    $destinationMetadata = Get-MetadataSnapshot -Path $DestinationPath
    foreach ($name in @('Title', 'ImageDescription', 'Description', 'XPTitle', 'XPSubject', 'Subject', 'Keywords', 'HierarchicalSubject', 'DateTimeOriginal', 'CreateDate'))
    {
        $sourceValue = ""
        if ($sourceMetadata.PSObject.Properties.Name -contains $name)
        {
            $sourceValue = Convert-MetadataValue $sourceMetadata.$name
        }

        if ([string]::IsNullOrWhiteSpace($sourceValue) -or $sourceValue -match '^0000[:\-]00[:\-]00')
        {
            continue
        }

        $destinationValue = ""
        if ($destinationMetadata.PSObject.Properties.Name -contains $name)
        {
            $destinationValue = Convert-MetadataValue $destinationMetadata.$name
        }

        if ($sourceValue -ne $destinationValue)
        {
            return $true
        }
    }

    return $false
}

function New-VideoPoster
{
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$Clip,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][bool]$IsHdr
    )

    if (-not (Test-Path -LiteralPath $OutputDir))
    {
        if ($WhatIf)
        {
            Write-Host "[WhatIf] New-Item -ItemType Directory -Path $OutputDir -Force"
        }
        else
        {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
    }

    $posterPath = Join-Path $OutputDir "poster.avif"

    $needsPoster = $true
    if (Test-Path -LiteralPath $posterPath)
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
        if ((-not $WhatIf) -and (Test-MetadataCopyNeeded -SourcePath $Clip.FullName -DestinationPath $posterPath))
        {
            Copy-Metadata -SourcePath $Clip.FullName -DestinationPath $posterPath
        }
        return
    }

    $resizePercent = if ($PosterScale -ne 100) { "{0}%" -f $PosterScale } else { $null }

    if ($IsHdr)
    {
        $tempPoster = Join-Path ([System.IO.Path]::GetTempPath()) ("hls-poster-{0}.png" -f ([guid]::NewGuid().ToString("N")))
        $posterFilter = Get-HdrToneMapFilter
        if ($PosterScale -ne 100)
        {
            $posterFilter = "$posterFilter,scale=iw*$PosterScale/100:ih*$PosterScale/100"
        }
        $posterFilter = "$posterFilter,format=rgb24"

        $ffmpegArgs = @(
            "-y",
            "-i", $Clip.FullName,
            "-map", "0:v:0",
            "-frames:v", "1",
            "-vf", $posterFilter,
            "-update", "1",
            $tempPoster
        )

        $magickArgs = @(
            $tempPoster,
            "-strip",
            "-quality",
            $PosterQuality.ToString(),
            $posterPath
        )

        if ($WhatIf)
        {
            Write-Host "[WhatIf] ffmpeg $($ffmpegArgs -join ' ')"
            Write-Host "[WhatIf] magick $($magickArgs -join ' ')"
            Write-Host "[WhatIf] exiftool -TagsFromFile $($Clip.FullName) ... $posterPath"
            return
        }

        try
        {
            Write-Host "Generating tone-mapped poster frame: $posterPath"
            & ffmpeg @ffmpegArgs
            if ($LASTEXITCODE -ne 0)
            {
                throw "ffmpeg failed while extracting tone-mapped poster for clip $($Clip.FullName)"
            }

            & magick @magickArgs
            if ($LASTEXITCODE -ne 0)
            {
                throw "magick failed while generating poster for clip $($Clip.FullName)"
            }
        }
        finally
        {
            if (Test-Path -LiteralPath $tempPoster)
            {
                Remove-Item -LiteralPath $tempPoster -Force
            }
        }

        Copy-Metadata -SourcePath $Clip.FullName -DestinationPath $posterPath
        return
    }

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
        Write-Host "[WhatIf] exiftool -TagsFromFile $($Clip.FullName) ... $posterPath"
        return
    }

    Write-Host "Generating poster frame: $posterPath"
    & magick @args
    if ($LASTEXITCODE -ne 0)
    {
        throw "magick failed while generating poster for clip $($Clip.FullName)"
    }

    Copy-Metadata -SourcePath $Clip.FullName -DestinationPath $posterPath
}

function Test-ObjectProperty
{
    param(
        $InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return (
        $null -ne $InputObject -and
        $null -ne $InputObject.PSObject -and
        @($InputObject.PSObject.Properties | Where-Object { $_.Name -eq $Name }).Count -gt 0
    )
}

function Get-DisplayVideoDimensions
{
    param($StreamInfo)

    $width = if (Test-ObjectProperty -InputObject $StreamInfo -Name "width") { [int]$StreamInfo.width } else { 0 }
    $height = if (Test-ObjectProperty -InputObject $StreamInfo -Name "height") { [int]$StreamInfo.height } else { 0 }

    $rotation = 0
    if ((Test-ObjectProperty -InputObject $StreamInfo -Name "tags") -and
        (Test-ObjectProperty -InputObject $StreamInfo.tags -Name "rotate"))
    {
        $rotation = [int]$StreamInfo.tags.rotate
    }

    if ([Math]::Abs($rotation) % 180 -eq 90)
    {
        return [pscustomobject]@{
            Width  = $height
            Height = $width
        }
    }

    return [pscustomobject]@{
        Width  = $width
        Height = $height
    }
}

function ConvertTo-EvenDimension
{
    param([Parameter(Mandatory = $true)][double]$Value)

    $dimension = [Math]::Floor($Value)
    if ($dimension % 2 -ne 0)
    {
        $dimension--
    }

    return [Math]::Max(2, [int]$dimension)
}

function New-Rendition
{
    param(
        [Parameter(Mandatory = $true)][hashtable]$BaseRendition,
        [Parameter(Mandatory = $true)][int]$SourceWidth,
        [Parameter(Mandatory = $true)][int]$SourceHeight
    )

    $maxWidth = [int]$BaseRendition["Width"]
    $maxHeight = [int]$BaseRendition["Height"]
    if ($SourceHeight -gt $SourceWidth)
    {
        $maxWidth = [int]$BaseRendition["Height"]
        $maxHeight = [int]$BaseRendition["Width"]
    }

    $scale = [Math]::Min($maxWidth / $SourceWidth, $maxHeight / $SourceHeight)

    return [pscustomobject]@{
        Name         = $BaseRendition["Name"]
        Width        = ConvertTo-EvenDimension ($SourceWidth * $scale)
        Height       = ConvertTo-EvenDimension ($SourceHeight * $scale)
        VideoBitrate = $BaseRendition["VideoBitrate"]
        MaxRate      = $BaseRendition["MaxRate"]
        BufferSize   = $BaseRendition["BufferSize"]
        AudioBitrate = $BaseRendition["AudioBitrate"]
        Bandwidth    = $BaseRendition["Bandwidth"]
    }
}

function Get-Renditions
{
    param($StreamInfo)

    $dimensions = Get-DisplayVideoDimensions -StreamInfo $StreamInfo
    $baseRenditions = @(
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

    if ($dimensions.Width -le 0 -or $dimensions.Height -le 0)
    {
        return @($baseRenditions | ForEach-Object { [pscustomobject]$_ })
    }

    $renditions = [System.Collections.ArrayList]::new()
    foreach ($baseRendition in $baseRenditions)
    {
        [void]$renditions.Add((New-Rendition -BaseRendition $baseRendition -SourceWidth $dimensions.Width -SourceHeight $dimensions.Height))
    }

    return @($renditions)
}

function Get-VideoStreamInfo
{
    param([Parameter(Mandatory = $true)][string]$InputFile)

    $args = @(
        "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height,pix_fmt,color_space,color_transfer,color_primaries:stream_tags=rotate",
        "-of", "json",
        $InputFile
    )

    $json = & ffprobe @args
    if ($LASTEXITCODE -ne 0)
    {
        throw "ffprobe failed while reading video stream info: $InputFile"
    }

    $info = $json | ConvertFrom-Json
    return $info.streams | Select-Object -First 1
}

function Test-HdrVideo
{
    param($StreamInfo)

    if ($null -eq $StreamInfo)
    {
        return $false
    }

    $pixFmt = if ($StreamInfo.PSObject.Properties.Name -contains "pix_fmt") { $StreamInfo.pix_fmt } else { "" }
    $transfer = if ($StreamInfo.PSObject.Properties.Name -contains "color_transfer") { $StreamInfo.color_transfer } else { "" }
    $primaries = if ($StreamInfo.PSObject.Properties.Name -contains "color_primaries") { $StreamInfo.color_primaries } else { "" }
    $space = if ($StreamInfo.PSObject.Properties.Name -contains "color_space") { $StreamInfo.color_space } else { "" }

    return (
        $pixFmt -match "10|12" -or
        $transfer -in @("arib-std-b67", "smpte2084") -or
        $primaries -eq "bt2020" -or
        $space -match "bt2020"
    )
}

function Get-HdrToneMapFilter
{
    return "zscale=transfer=linear:npl=100,format=gbrpf32le,zscale=primaries=bt709,tonemap=tonemap=hable:desat=0,zscale=transfer=bt709:matrix=bt709:range=tv"
}

function Get-VideoFilter
{
    param(
        [Parameter(Mandatory = $true)]$Rendition,
        [Parameter(Mandatory = $true)][bool]$IsHdr
    )

    $width = $Rendition.Width
    $height = $Rendition.Height
    $resizeFilter = "scale=w=$($width):h=$($height),setsar=1"
    if (-not $IsHdr)
    {
        return "$resizeFilter,format=yuv420p"
    }

    return "$(Get-HdrToneMapFilter),$resizeFilter,format=yuv420p"
}

function New-HlsVariant
{
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)]$Rendition,
        [Parameter(Mandatory = $true)][bool]$IsHdr
    )

    $renditionName = $Rendition.Name
    $videoBitrate = $Rendition.VideoBitrate
    $maxRate = $Rendition.MaxRate
    $bufferSize = $Rendition.BufferSize
    $audioBitrate = $Rendition.AudioBitrate
    $variantDir = Join-Path $OutputDir $renditionName
    if ($WhatIf)
    {
        Write-Host "[WhatIf] New-Item -ItemType Directory -Path $variantDir -Force"
    }
    else
    {
        New-Item -ItemType Directory -Path $variantDir -Force | Out-Null
    }

    $playlistPath = Join-Path $variantDir "index.m3u8"
    $segmentPattern = Join-Path $variantDir "seg_%03d.ts"

    $args = @(
        "-y",
        "-i", $InputFile,
        "-map", "0:v:0",
        "-map", "0:a:0?",
        "-vf", (Get-VideoFilter -Rendition $Rendition -IsHdr $IsHdr),
        "-c:v", "libx264",
        "-profile:v", "high",
        "-pix_fmt", "yuv420p",
        "-preset", "medium",
        "-g", "48",
        "-keyint_min", "48",
        "-sc_threshold", "0",
        "-b:v", $videoBitrate,
        "-maxrate", $maxRate,
        "-bufsize", $bufferSize,
        "-c:a", "aac",
        "-b:a", $audioBitrate,
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

    Write-Host "Encoding $renditionName from $InputFile"
    & ffmpeg @args
    if ($LASTEXITCODE -ne 0)
    {
        throw "ffmpeg failed for rendition ${renditionName}: $InputFile"
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
        $bandwidth = $rendition.Bandwidth
        $width = $rendition.Width
        $height = $rendition.Height
        $name = $rendition.Name
        $lines += "#EXT-X-STREAM-INF:BANDWIDTH=$bandwidth,RESOLUTION=$($width)x$height"
        $lines += "$name/index.m3u8"
    }

    if ($WhatIf)
    {
        Write-Host "[WhatIf] Set-Content -Path $masterPath -Encoding UTF8"
        return
    }

    Set-Content -Path $masterPath -Value $lines -Encoding UTF8
}

function Convert-ClipToHls
{
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$Clip
    )

    # Keep HLS outputs under the post's root media folder even when
    # the source clip lives in a subfolder like "video-src".
    $clipDir = $Clip.Directory
    $postDir = if ($clipDir.Name -ieq "video-src") { $clipDir.Parent } else { $clipDir }

    $streamRoot = Join-Path $postDir.FullName "stream"
    $outputDir = Join-Path $streamRoot $Clip.BaseName

    $streamInfo = Get-VideoStreamInfo -InputFile $Clip.FullName
    $isHdr = Test-HdrVideo -StreamInfo $streamInfo
    if ($isHdr)
    {
        Write-Host "Detected HDR/BT.2020 source; applying SDR tone mapping: $($Clip.FullName)"
    }

    if ((Test-Path $outputDir) -and -not $Rebuild)
    {
        New-VideoPoster -Clip $Clip -OutputDir $outputDir -IsHdr $isHdr
        Write-Host "Skipping existing HLS output: $outputDir"
        return
    }

    if (Test-Path $outputDir)
    {
        if ($WhatIf)
        {
            Write-Host "[WhatIf] Remove-Item -Path $outputDir -Recurse -Force"
        }
        else
        {
            Remove-Item -Path $outputDir -Recurse -Force
        }
    }

    if ($WhatIf)
    {
        Write-Host "[WhatIf] New-Item -ItemType Directory -Path $outputDir -Force"
    }
    else
    {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $renditions = Get-Renditions -StreamInfo $streamInfo

    foreach ($rendition in $renditions)
    {
        New-HlsVariant -InputFile $Clip.FullName -OutputDir $outputDir -Rendition $rendition -IsHdr $isHdr
    }

    New-MasterPlaylist -OutputDir $outputDir -Renditions $renditions
    New-VideoPoster -Clip $Clip -OutputDir $outputDir -IsHdr $isHdr
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
    # Scan recursively so source clips can live in a nested folder such as
    # "video-src" without affecting the location of derived outputs.
    $clips += Get-ChildItem -Path $postDir -Filter "*.mp4" -File -Recurse -ErrorAction SilentlyContinue
    $clips += Get-ChildItem -Path $postDir -Filter "*.mov" -File -Recurse -ErrorAction SilentlyContinue

    foreach ($clip in $clips)
    {
        Convert-ClipToHls -Clip $clip
    }
}

Write-Host "Done."
