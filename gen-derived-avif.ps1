<#
.SYNOPSIS
Builds AVIF derivatives for post images.

.DESCRIPTION
Discovers primary images within each post folder, generates full-size AVIF files beside
the source images capped to a maximum dimension, and generates AVIF derivatives for
`thumbnails/` and `tinyfiles/` when the source EXIF tags include `thumbnail` or `gallery`
respectively. ImageMagick's `magick` tool performs every conversion so that generated
assets stay synchronized with the primary media. Existing generated assets are refreshed
only when the source is newer unless -Force is specified.

By default, SourcePath is treated as the posts media root (`assets/img/posts`) and every
child post folder is processed. For a faster new-post workflow, pass a specific post
folder with -SourcePath or -PostPath, or pass one or more slugs with -PostSlug.
#>
[CmdletBinding()]
param(
    [string]$SourcePath = ".\assets\img\posts",
    [string[]]$PostSlug,
    [string[]]$PostPath,
    [switch]$Force,
    [switch]$PruneLegacy,
    [switch]$PruneUntaggedDerived,
    [ValidateRange(1, 4096)]
    [int]$ThumbnailWidth = 480,
    [ValidateRange(1, 4096)]
    [int]$Thumbnail2xWidth = 960,
    [ValidateRange(1, 8192)]
    [int]$MaxDimension = 2048,
    [ValidateRange(1, 100)]
    [int]$TinyfileScale = 10,
    [ValidateRange(0, 100)]
    [int]$Quality = 75
)

$ErrorActionPreference = "Stop"

function Write-Info
{
    param([string]$Message)
    Write-Host "[AVIF-Derived] $Message" -ForegroundColor Cyan
}

function Write-WarningMessage
{
    param([string]$Message)
    Write-Host "[AVIF-Derived] $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage
{
    param([string]$Message)
    Write-Host "[AVIF-Derived] $Message" -ForegroundColor Red
}

function Get-TagTokens
{
    param(
        [System.__ComObject]$ShellFolder,
        [System.__ComObject]$ShellFile,
        [int]$TagIndex
    )

    if (-not $ShellFile)
    {
        return @()
    }

    $raw = $ShellFolder.GetDetailsOf($ShellFile, $TagIndex)
    if ([string]::IsNullOrWhiteSpace($raw))
    {
        return @()
    }

    return $raw -split "\s*;\s*" | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() }
}

function ShouldRebuild
{
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Destination))
    {
        return $true
    }

    try
    {
        $sourceInfo = Get-Item -LiteralPath $Source
        $destInfo = Get-Item -LiteralPath $Destination
        return $sourceInfo.LastWriteTimeUtc -gt $destInfo.LastWriteTimeUtc
    }
    catch
    {
        Write-WarningMessage "Failed to compare timestamps for '$Destination'. Regenerating."
        return $true
    }
}

function Remove-Derived
{
    param(
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Destination)
    {
        Remove-Item -LiteralPath $Destination -Force
    }
}

# Wrapper around ImageMagick for consistent argument handling.
function Invoke-MagickEncode
{
    param(
        [string]$InputPath,
        [string]$DestinationPath,
        [string]$ResizeGeometry,
        [Nullable[int]]$QualityValue,
        [switch]$StripMetadata
    )

    $arguments = @()
    $arguments += $InputPath
    if ($ResizeGeometry)
    {
        $arguments += "-resize"
        $arguments += $ResizeGeometry
    }
    if ($StripMetadata)
    {
        $arguments += "-strip"
    }
    if ($null -ne $QualityValue)
    {
        $arguments += "-quality"
        $arguments += $QualityValue.ToString()
    }
    $arguments += $DestinationPath

    Write-Info "magick $($arguments -join ' ')"
    & $script:MagickExecutable $arguments
    if ($LASTEXITCODE -ne 0)
    {
        throw "magick exited with code $LASTEXITCODE"
    }
}

function Get-PrimaryImages
{
    param([Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$Folder)

    return @(Get-ChildItem -LiteralPath $Folder.FullName -File |
        Where-Object { @('.jpeg', '.jpg', '.heic', '.png') -contains $_.Extension.ToLowerInvariant() })
}

function ConvertTo-BoolValue
{
    param($Value)

    if ($null -eq $Value)
    {
        return $false
    }

    return @('true', 'yes', '1', 'on') -contains $Value.ToString().Trim().ToLowerInvariant()
}

function Read-MediaManifest
{
    param([Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$Folder)

    $manifestPath = Join-Path -Path $Folder.FullName -ChildPath "media.yml"
    if (-not (Test-Path -LiteralPath $manifestPath))
    {
        return $null
    }

    $manifest = [ordered]@{
        Cover = ""
        Images = @()
    }
    $current = $null

    foreach ($line in Get-Content -LiteralPath $manifestPath)
    {
        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line))
        {
            continue
        }

        if ($line -match '^\s*cover:\s*(.+?)\s*$')
        {
            $manifest.Cover = $matches[1].Trim().Trim('"').Trim("'")
            continue
        }

        if ($line -match '^\s*-\s*source:\s*(.+?)\s*$')
        {
            if ($current)
            {
                $manifest.Images += [pscustomobject]$current
            }

            $current = [ordered]@{
                Source = $matches[1].Trim().Trim('"').Trim("'")
                Include = $false
                Gallery = $false
                Thumbnail = $false
                Caption = ""
            }
            continue
        }

        if ($current -and $line -match '^\s*(include|gallery|thumbnail|caption):\s*(.*?)\s*$')
        {
            $key = $matches[1].ToLowerInvariant()
            $value = $matches[2].Trim().Trim('"').Trim("'")
            switch ($key)
            {
                'include' { $current.Include = ConvertTo-BoolValue $value }
                'gallery' { $current.Gallery = ConvertTo-BoolValue $value }
                'thumbnail' { $current.Thumbnail = ConvertTo-BoolValue $value }
                'caption' { $current.Caption = $value }
            }
        }
    }

    if ($current)
    {
        $manifest.Images += [pscustomobject]$current
    }

    return [pscustomobject]$manifest
}

function Get-ManifestImageFile
{
    param(
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$Folder,
        [Parameter(Mandatory = $true)]$ManifestImage
    )

    $sourcePath = Join-Path -Path $Folder.FullName -ChildPath $ManifestImage.Source
    if (Test-Path -LiteralPath $sourcePath)
    {
        return Get-Item -LiteralPath $sourcePath
    }

    Write-WarningMessage "Manifest source '$($ManifestImage.Source)' was not found in '$($Folder.FullName)'."
    return $null
}

function Resolve-PostFolders
{
    param(
        [Parameter(Mandatory = $true)][string]$BaseSourcePath,
        [string[]]$Slugs,
        [string[]]$Paths
    )

    $foldersByPath = [ordered]@{}

    if ($Paths -and $Paths.Count -gt 0)
    {
        foreach ($path in $Paths)
        {
            if (-not (Test-Path -LiteralPath $path))
            {
                throw "Post path '$path' was not found."
            }

            $item = Get-Item -LiteralPath $path
            if (-not $item.PSIsContainer)
            {
                throw "Post path '$path' is not a directory."
            }

            $foldersByPath[$item.FullName] = [System.IO.DirectoryInfo]$item
        }

        return @($foldersByPath.Values)
    }

    if (-not (Test-Path -LiteralPath $BaseSourcePath))
    {
        throw "Source path '$BaseSourcePath' was not found."
    }

    $sourceItem = Get-Item -LiteralPath $BaseSourcePath
    if (-not $sourceItem.PSIsContainer)
    {
        throw "Source path '$BaseSourcePath' is not a directory."
    }

    if ($Slugs -and $Slugs.Count -gt 0)
    {
        foreach ($slug in $Slugs)
        {
            if ([string]::IsNullOrWhiteSpace($slug))
            {
                continue
            }

            $candidate = Join-Path -Path $sourceItem.FullName -ChildPath $slug.Trim()
            if (-not (Test-Path -LiteralPath $candidate))
            {
                throw "Post slug '$slug' was not found under '$($sourceItem.FullName)'."
            }

            $item = Get-Item -LiteralPath $candidate
            if (-not $item.PSIsContainer)
            {
                throw "Post slug '$slug' resolved to a non-directory path."
            }

            $foldersByPath[$item.FullName] = [System.IO.DirectoryInfo]$item
        }

        return @($foldersByPath.Values)
    }

    $sourceDirectory = [System.IO.DirectoryInfo]$sourceItem
    if ((Get-PrimaryImages -Folder $sourceDirectory).Count -gt 0)
    {
        return @($sourceDirectory)
    }

    return @(Get-ChildItem -LiteralPath $sourceDirectory.FullName -Directory)
}

try
{
    $script:MagickExecutable = (Get-Command "magick" -ErrorAction Stop).Source
}
catch
{
    Write-ErrorMessage "ImageMagick 'magick' executable not found on PATH."
    exit 1
}

try
{
    $postFolders = @(Resolve-PostFolders -BaseSourcePath $SourcePath -Slugs $PostSlug -Paths $PostPath)
}
catch
{
    Write-ErrorMessage $_.Exception.Message
    exit 1
}

if ($postFolders.Count -eq 0)
{
    Write-WarningMessage "No post folders found to process."
    exit 0
}

Write-Info "Building derived AVIF assets for $($postFolders.Count) post folder(s)."

$shell = New-Object -ComObject Shell.Application
$tagIndex = 18

foreach ($postFolder in $postFolders)
{
    Write-Info "Processing folder '$($postFolder.FullName)'."

    $thumbnailsPath = Join-Path -Path $postFolder.FullName -ChildPath "thumbnails"
    $thumbnails2xPath = Join-Path -Path $postFolder.FullName -ChildPath "thumbnails-2x"
    $tinyfilesPath = Join-Path -Path $postFolder.FullName -ChildPath "tinyfiles"
    $null = New-Item -Path $thumbnailsPath -ItemType Directory -Force
    $null = New-Item -Path $thumbnails2xPath -ItemType Directory -Force
    $null = New-Item -Path $tinyfilesPath -ItemType Directory -Force

    if ($PruneLegacy)
    {
        Get-ChildItem -Path $thumbnailsPath -Include *.jpg, *.jpeg, *.png -File -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path $thumbnails2xPath -Include *.jpg, *.jpeg, *.png -File -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path $tinyfilesPath -Include *.jpg, *.jpeg, *.png -File -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    $manifest = Read-MediaManifest -Folder $postFolder
    $imagesToProcess = @()

    if ($manifest -and $manifest.Images.Count -gt 0)
    {
        Write-Info "Using media.yml intent for '$($postFolder.Name)'."
        foreach ($manifestImage in $manifest.Images)
        {
            $imageFile = Get-ManifestImageFile -Folder $postFolder -ManifestImage $manifestImage
            if ($imageFile)
            {
                $imagesToProcess += [pscustomobject]@{
                    File = $imageFile
                    NeedsThumbnail = [bool]$manifestImage.Thumbnail
                    NeedsTinyfile = [bool]$manifestImage.Gallery
                }
            }
        }
    }
    else
    {
        $primaryImages = Get-PrimaryImages -Folder $postFolder
        foreach ($image in $primaryImages)
        {
            $shellFolder = $shell.Namespace($image.DirectoryName)
            $shellFile = $shellFolder.ParseName($image.Name)
            $tagTokens = Get-TagTokens -ShellFolder $shellFolder -ShellFile $shellFile -TagIndex $tagIndex

            $imagesToProcess += [pscustomobject]@{
                File = $image
                NeedsThumbnail = $tagTokens -contains "thumbnail"
                NeedsTinyfile = $tagTokens -contains "gallery"
            }
        }
    }

    foreach ($imageSpec in $imagesToProcess)
    {
        $image = $imageSpec.File
        $needsThumbnail = $imageSpec.NeedsThumbnail
        $needsTinyfile = $imageSpec.NeedsTinyfile

        $fullSizeTarget = Join-Path -Path $postFolder.FullName -ChildPath ($image.BaseName + ".avif")
        $thumbnailTarget = Join-Path -Path $thumbnailsPath -ChildPath ($image.BaseName + ".avif")
        $thumbnail2xTarget = Join-Path -Path $thumbnails2xPath -ChildPath ($image.BaseName + ".avif")
        $tinyfileTarget = Join-Path -Path $tinyfilesPath -ChildPath ($image.BaseName + ".avif")

        if ($image.Extension.ToLowerInvariant() -ne ".avif" -and ($Force -or (ShouldRebuild -Source $image.FullName -Destination $fullSizeTarget)))
        {
            Invoke-MagickEncode -InputPath $image.FullName -DestinationPath $fullSizeTarget -ResizeGeometry ("${MaxDimension}x${MaxDimension}>") -QualityValue $null
        }

        if ($needsThumbnail)
        {
            if ($Force -or (ShouldRebuild -Source $image.FullName -Destination $thumbnailTarget))
            {
                Invoke-MagickEncode -InputPath $image.FullName -DestinationPath $thumbnailTarget -ResizeGeometry ("${ThumbnailWidth}x>") -QualityValue $Quality -StripMetadata
            }
            if ($Force -or (ShouldRebuild -Source $image.FullName -Destination $thumbnail2xTarget))
            {
                Invoke-MagickEncode -InputPath $image.FullName -DestinationPath $thumbnail2xTarget -ResizeGeometry ("${Thumbnail2xWidth}x>") -QualityValue $Quality -StripMetadata
            }
        }
        else
        {
            if ($PruneUntaggedDerived)
            {
                Remove-Derived -Destination $thumbnailTarget
                Remove-Derived -Destination $thumbnail2xTarget
            }
        }

        if ($needsTinyfile)
        {
            if ($Force -or (ShouldRebuild -Source $image.FullName -Destination $tinyfileTarget))
            {
                Invoke-MagickEncode -InputPath $image.FullName -DestinationPath $tinyfileTarget -ResizeGeometry ("$TinyfileScale%") -QualityValue $Quality -StripMetadata
            }
        }
        else
        {
            if ($PruneUntaggedDerived)
            {
                Remove-Derived -Destination $tinyfileTarget
            }
        }
    }

}

Write-Info "Derived AVIF generation complete."
