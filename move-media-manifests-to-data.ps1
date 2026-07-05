#Requires -Version 5.1
<#
.SYNOPSIS
Copies per-post media manifests into _data/media.

.DESCRIPTION
Reads legacy assets/img/posts/<slug>/media.yml files and writes keyed Jekyll data
manifests to _data/media/<slug>.yml. Legacy files are left in place so the
migration can be verified before any cleanup.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$MediaRoot = ".\assets\img\posts",
    [string]$DataRoot = ".\_data\media",
    [string[]]$Slug,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $RepoRoot "media-manifest.ps1")

function Write-Info {
    param([string]$Message)
    Write-Host "[media-data] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[media-data] WARN: $Message" -ForegroundColor Yellow
}

Push-Location $RepoRoot
try {
    if (-not (Test-Path -LiteralPath $MediaRoot)) {
        throw "Media root was not found: $MediaRoot"
    }

    $selectedSlugs = @{}
    foreach ($item in @($Slug)) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $selectedSlugs[$item.Trim().ToLowerInvariant()] = $true
        }
    }

    $legacyManifests = @(Get-ChildItem -Path $MediaRoot -Filter "media.yml" -File -Recurse)
    $written = 0
    $skipped = 0

    foreach ($legacyManifest in $legacyManifests) {
        $postFolder = $legacyManifest.Directory
        $postSlug = $postFolder.Name
        if ($selectedSlugs.Count -gt 0 -and -not $selectedSlugs.ContainsKey($postSlug.ToLowerInvariant())) {
            continue
        }

        $manifest = Read-MediaManifestFile -ManifestPath $legacyManifest.FullName
        if (-not $manifest) {
            Write-Warn "Could not read $($legacyManifest.FullName)."
            $skipped++
            continue
        }

        $targetPath = Join-Path $DataRoot "$postSlug.yml"
        if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
            Write-Info "Skipping $postSlug; $targetPath already exists. Use -Force to overwrite."
            $skipped++
            continue
        }

        if ($PSCmdlet.ShouldProcess($targetPath, "Write media data manifest")) {
            Write-MediaManifestFile -ManifestPath $targetPath -Manifest $manifest
            Write-Info "Wrote $targetPath"
            $written++
        }
    }

    Write-Info "Complete. Wrote $written manifest(s), skipped $skipped."
}
finally {
    Pop-Location
}
