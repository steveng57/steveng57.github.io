<#
.SYNOPSIS
Builds AVIF derivatives for post media from primary JPEG and HEIC assets.

.DESCRIPTION
Discovers primary images within each post folder and generates AVIF derivatives for
`thumbnails/` and `tinyfiles/` when the source EXIF tags include `thumbnail` or `gallery`
respectively. Poster frames for MP4 clips are captured as AVIF as well. ImageMagick's
`magick` tool performs every conversion so that derived assets stay synchronized with the
primary media. Existing derivatives are refreshed only when the source is newer unless
-Force is specified.

.PARAMETER PosterScale
Sets the resize percentage for video poster frames (default 100 to keep native dimensions).
#>
param(
    [string]$SourcePath = ".\assets\img\posts",
    [switch]$Force,
    [switch]$PruneLegacy,
    [ValidateRange(1,100)]
    [int]$ThumbnailScale = 50,
    [ValidateRange(1,200)]
    [int]$Thumbnail2xScale = 100,
    [ValidateRange(1,100)]
    [int]$TinyfileScale = 10,
    [ValidateRange(1,200)]
    [int]$PosterScale = 100,
    [ValidateRange(0,100)]
    [int]$Quality = 75
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[AVIF-Derived] $Message" -ForegroundColor Cyan
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[AVIF-Derived] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[AVIF-Derived] $Message" -ForegroundColor Red
}

function Get-TagTokens {
    param(
        [System.__ComObject]$ShellFolder,
        [System.__ComObject]$ShellFile,
        [int]$TagIndex
    )

    if (-not $ShellFile) {
        return @()
    }

    $raw = $ShellFolder.GetDetailsOf($ShellFile, $TagIndex)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    return $raw -split "\s*;\s*" | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() }
}

function ShouldRebuild {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Destination)) {
        return $true
    }

    try {
        $sourceInfo = Get-Item -LiteralPath $Source
        $destInfo = Get-Item -LiteralPath $Destination
        return $sourceInfo.LastWriteTimeUtc -gt $destInfo.LastWriteTimeUtc
    } catch {
        Write-WarningMessage "Failed to compare timestamps for '$Destination'. Regenerating."
        return $true
    }
}

function Remove-Derived {
    param(
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Force
    }
}

# Wrapper around ImageMagick for consistent argument handling.
function Invoke-MagickEncode {
    param(
        [string]$InputPath,
        [string]$DestinationPath,
        [string]$ResizePercent,
        [int]$QualityValue,
        [switch]$VideoFrame
    )

    $inputArgument = $InputPath
    if ($VideoFrame) {
        $inputArgument = "${InputPath}[0]"
    }

    $arguments = @()
    $arguments += $inputArgument
    if ($ResizePercent) {
        $arguments += "-resize"
        $arguments += $ResizePercent
    }
    $arguments += "-strip"
    $arguments += "-quality"
    $arguments += $QualityValue.ToString()
    $arguments += $DestinationPath

    Write-Info "magick $($arguments -join ' ')"
    & $script:MagickExecutable $arguments
    if ($LASTEXITCODE -ne 0) {
        throw "magick exited with code $LASTEXITCODE"
    }
}

try {
    $script:MagickExecutable = (Get-Command "magick" -ErrorAction Stop).Source
} catch {
    Write-ErrorMessage "ImageMagick 'magick' executable not found on PATH."
    exit 1
}

if (-not (Test-Path -LiteralPath $SourcePath)) {
    Write-ErrorMessage "Source path '$SourcePath' was not found."
    exit 1
}

$resolvedSource = Resolve-Path -Path $SourcePath
Write-Info "Building derived AVIF assets under '$resolvedSource'."

$shell = New-Object -ComObject Shell.Application
$tagIndex = 18

# Enumerate each post folder and keep derivatives in sync with tag metadata.
$postFolders = Get-ChildItem -Path $resolvedSource -Directory
foreach ($postFolder in $postFolders) {
    Write-Info "Processing folder '$($postFolder.FullName)'."

    $thumbnailsPath = Join-Path -Path $postFolder.FullName -ChildPath "thumbnails"
    $thumbnails2xPath = Join-Path -Path $postFolder.FullName -ChildPath "thumbnails-2x"
    $tinyfilesPath = Join-Path -Path $postFolder.FullName -ChildPath "tinyfiles"
    $null = New-Item -Path $thumbnailsPath -ItemType Directory -Force
    $null = New-Item -Path $thumbnails2xPath -ItemType Directory -Force
    $null = New-Item -Path $tinyfilesPath -ItemType Directory -Force

    if ($PruneLegacy) {
        Get-ChildItem -Path $thumbnailsPath -Include *.jpg, *.jpeg, *.png -File -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path $thumbnails2xPath -Include *.jpg, *.jpeg, *.png -File -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path $tinyfilesPath -Include *.jpg, *.jpeg, *.png -File -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    $primaryImages = Get-ChildItem -Path $postFolder.FullName -File |
        Where-Object { @('.jpeg', '.jpg', '.heic', '.png') -contains $_.Extension.ToLowerInvariant() }

    foreach ($image in $primaryImages) {
        $shellFolder = $shell.Namespace($image.DirectoryName)
        $shellFile = $shellFolder.ParseName($image.Name)
        $tagTokens = Get-TagTokens -ShellFolder $shellFolder -ShellFile $shellFile -TagIndex $tagIndex

        $needsThumbnail = $tagTokens -contains "thumbnail"
        $needsTinyfile = $tagTokens -contains "gallery"

        $thumbnailTarget = Join-Path -Path $thumbnailsPath -ChildPath ($image.BaseName + ".avif")
        $thumbnail2xTarget = Join-Path -Path $thumbnails2xPath -ChildPath ($image.BaseName + ".avif")
        $tinyfileTarget = Join-Path -Path $tinyfilesPath -ChildPath ($image.BaseName + ".avif")

        if ($needsThumbnail) {
            if ($Force -or (ShouldRebuild -Source $image.FullName -Destination $thumbnailTarget)) {
                Invoke-MagickEncode -InputPath $image.FullName -DestinationPath $thumbnailTarget -ResizePercent ("$ThumbnailScale%") -QualityValue $Quality
            }
            if ($Force -or (ShouldRebuild -Source $image.FullName -Destination $thumbnail2xTarget)) {
                $resize2x = if ($Thumbnail2xScale -ne 100) { "$Thumbnail2xScale%" } else { $null }
                Invoke-MagickEncode -InputPath $image.FullName -DestinationPath $thumbnail2xTarget -ResizePercent $resize2x -QualityValue $Quality
            }
        } else {
            Remove-Derived -Destination $thumbnailTarget
            Remove-Derived -Destination $thumbnail2xTarget
        }

        if ($needsTinyfile) {
            if ($Force -or (ShouldRebuild -Source $image.FullName -Destination $tinyfileTarget)) {
                Invoke-MagickEncode -InputPath $image.FullName -DestinationPath $tinyfileTarget -ResizePercent ("$TinyfileScale%") -QualityValue $Quality
            }
        } else {
            Remove-Derived -Destination $tinyfileTarget
        }
    }

    $videoFiles = Get-ChildItem -Path $postFolder.FullName -Filter "*.mp4" -File -ErrorAction SilentlyContinue
    foreach ($video in $videoFiles) {
        $posterTarget = Join-Path -Path $thumbnailsPath -ChildPath ($video.BaseName + ".avif")
        if ($Force -or (ShouldRebuild -Source $video.FullName -Destination $posterTarget)) {
            $posterResize = if ($PosterScale -ne 100) { "$PosterScale%" } else { $null }
            Invoke-MagickEncode -InputPath $video.FullName -DestinationPath $posterTarget -ResizePercent $posterResize -QualityValue $Quality -VideoFrame
        }
    }
}

Write-Info "Derived AVIF generation complete."