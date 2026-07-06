#Requires -Version 5.1
<#
.SYNOPSIS
Validates all post media manifests against files in assets/img/posts.

.EXAMPLE
.\test-media-manifests.ps1

.EXAMPLE
.\test-media-manifests.ps1 -Slug sauna-picture-frames

.EXAMPLE
.\test-media-manifests.ps1 -TreatWarningsAsErrors
#>

[CmdletBinding()]
param(
    [string]$Slug,
    [switch]$TreatWarningsAsErrors
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $RepoRoot "media-manifest.ps1")

$script:ErrorCount = 0
$script:WarningCount = 0

function Write-MediaError {
    param([string]$Message)
    $script:ErrorCount++
    Write-Host "[media-check] ERROR: $Message" -ForegroundColor Red
}

function Write-MediaWarning {
    param([string]$Message)
    $script:WarningCount++
    Write-Host "[media-check] WARN: $Message" -ForegroundColor Yellow
}

function Write-MediaOk {
    param([string]$Message)
    Write-Verbose "[media-check] OK: $Message"
}

function Test-SiteRelativeName {
    param(
        [string]$Value,
        [string]$Context
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-MediaError "$Context is empty."
        return $false
    }

    if ([System.IO.Path]::IsPathRooted($Value) -or $Value -match '^[a-z]+://') {
        Write-MediaError "$Context must be relative to the post media folder: $Value"
        return $false
    }

    $parts = $Value -split '[\\/]'
    if ($parts -contains '..') {
        Write-MediaError "$Context cannot contain '..': $Value"
        return $false
    }

    return $true
}

function Test-ExistingFile {
    param(
        [string]$MediaDir,
        [string]$RelativePath,
        [string]$Context,
        [switch]$WarningOnly
    )

    if (-not (Test-SiteRelativeName -Value $RelativePath -Context $Context)) {
        return
    }

    $path = Join-Path $MediaDir ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Write-MediaOk "$Context exists: $RelativePath"
        return
    }

    if ($WarningOnly) {
        Write-MediaWarning "$Context is not generated yet: $RelativePath"
    }
    else {
        Write-MediaError "$Context is missing: $RelativePath"
    }
}

function Test-DuplicateValue {
    param(
        [object[]]$Items,
        [scriptblock]$Selector,
        [string]$Context
    )

    $seen = @{}
    foreach ($item in @($Items)) {
        $value = (& $Selector $item)
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        if ($seen.ContainsKey($value)) {
            Write-MediaError "$Context is duplicated: $value"
        }
        else {
            $seen[$value] = $true
        }
    }
}

function Test-MediaManifestFile {
    param(
        [System.IO.FileInfo]$ManifestFile,
        [string]$AssetsRoot
    )

    $slug = [System.IO.Path]::GetFileNameWithoutExtension($ManifestFile.Name)
    $mediaDir = Join-Path $AssetsRoot $slug
    Write-Verbose "[media-check] Checking $slug"

    if (-not (Test-Path -LiteralPath $mediaDir -PathType Container)) {
        Write-MediaError "media folder is missing for manifest: assets/img/posts/$slug"
        return
    }

    $manifest = Read-MediaManifestFile -ManifestPath $ManifestFile.FullName
    if (-not $manifest) {
        Write-MediaError "manifest could not be read: $($ManifestFile.FullName)"
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($manifest.Cover)) {
        Test-ExistingFile -MediaDir $mediaDir -RelativePath $manifest.Cover -Context "$slug cover"
    }

    Test-DuplicateValue -Items $manifest.Images -Selector { param($item) Get-PublishedImageName -Image $item } -Context "$slug image published key"
    Test-DuplicateValue -Items $manifest.Images -Selector { param($item) $item.Source } -Context "$slug image source"
    Test-DuplicateValue -Items $manifest.Videos -Selector { param($item) Get-PublishedVideoName -Video $item } -Context "$slug video published key"
    Test-DuplicateValue -Items $manifest.Videos -Selector { param($item) $item.Source } -Context "$slug video source"

    foreach ($image in @($manifest.Images)) {
        $published = Get-PublishedImageName -Image $image
        $label = "$slug image $published"

        Test-ExistingFile -MediaDir $mediaDir -RelativePath $image.Source -Context "$label source"
        Test-ExistingFile -MediaDir $mediaDir -RelativePath $published -Context "$label published file" -WarningOnly

        if ($image.Thumbnail) {
            Test-ExistingFile -MediaDir $mediaDir -RelativePath "thumbnails/$published" -Context "$label thumbnail" -WarningOnly
            Test-ExistingFile -MediaDir $mediaDir -RelativePath "thumbnails-2x/$published" -Context "$label 2x thumbnail" -WarningOnly
        }

        if ($image.Gallery) {
            Test-ExistingFile -MediaDir $mediaDir -RelativePath "tinyfiles/$published" -Context "$label gallery tinyfile" -WarningOnly
        }
    }

    foreach ($video in @($manifest.Videos)) {
        $published = Get-PublishedVideoName -Video $video
        $label = "$slug video $published"

        Test-ExistingFile -MediaDir $mediaDir -RelativePath $video.Source -Context "$label source"
        Test-ExistingFile -MediaDir $mediaDir -RelativePath $published -Context "$label HLS master" -WarningOnly

        if (-not [string]::IsNullOrWhiteSpace($video.Poster)) {
            Test-ExistingFile -MediaDir $mediaDir -RelativePath $video.Poster -Context "$label poster" -WarningOnly
        }
    }
}

$mediaDataDir = Get-MediaDataDirectory -RepoRoot $RepoRoot
$assetsRoot = Join-Path (Join-Path (Join-Path $RepoRoot "assets") "img") "posts"

if (-not (Test-Path -LiteralPath $mediaDataDir -PathType Container)) {
    throw "Media manifest directory does not exist: $mediaDataDir"
}

if (-not (Test-Path -LiteralPath $assetsRoot -PathType Container)) {
    throw "Post media directory does not exist: $assetsRoot"
}

$manifestFiles = if ([string]::IsNullOrWhiteSpace($Slug)) {
    @(Get-ChildItem -LiteralPath $mediaDataDir -Filter "*.yml" -File | Sort-Object Name)
}
else {
    $manifestPath = Get-MediaManifestPath -Slug $Slug -RepoRoot $RepoRoot
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Media manifest does not exist for slug '$Slug': $manifestPath"
    }

    @(Get-Item -LiteralPath $manifestPath)
}

foreach ($manifestFile in $manifestFiles) {
    Test-MediaManifestFile -ManifestFile $manifestFile -AssetsRoot $assetsRoot
}

$legacyFiles = @(Get-ChildItem -LiteralPath $assetsRoot -Filter "media.yml" -File -Recurse)
foreach ($legacyFile in $legacyFiles) {
    Write-MediaWarning "legacy media.yml remains under assets/img/posts: $($legacyFile.FullName)"
}

if ($TreatWarningsAsErrors -and $script:WarningCount -gt 0) {
    $script:ErrorCount += $script:WarningCount
}

if ($script:ErrorCount -gt 0) {
    Write-Host "[media-check] Completed with $script:ErrorCount error(s) and $script:WarningCount warning(s)." -ForegroundColor Red
    exit 1
}

Write-Host "[media-check] Completed with no errors and $script:WarningCount warning(s)." -ForegroundColor Green
