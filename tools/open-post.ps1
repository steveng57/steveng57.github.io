param(
  [string]$Slug,
  [string]$Path,
  [switch]$NoExplorer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')

function Get-SlugFromPostPath {
  param([string]$InputPath)

  $name = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
  if ($name -match '^\d{4}-\d{2}-\d{2}-(.+)$') {
    return $Matches[1]
  }

  if ($InputPath -match '[\\/]_data[\\/]media[\\/]([^\\/]+)\.ya?ml$') {
    return $Matches[1]
  }

  if ($InputPath -match '[\\/]assets[\\/]img[\\/]posts[\\/]([^\\/]+)(?:[\\/]|$)') {
    return $Matches[1]
  }

  return $null
}

if ([string]::IsNullOrWhiteSpace($Slug) -and -not [string]::IsNullOrWhiteSpace($Path)) {
  $Slug = Get-SlugFromPostPath -InputPath $Path
}

if ([string]::IsNullOrWhiteSpace($Slug)) {
  throw 'Pass -Slug, or run this from a post Markdown file, media YAML file, or asset under assets/img/posts/<slug>.'
}

$Slug = $Slug.Trim()
$postRoot = Join-Path $repoRoot '_posts'
$mediaFile = Join-Path $repoRoot "_data\media\$Slug.yml"
$imgInfoFile = Join-Path $repoRoot '_data\img-info.json'
$assetDir = Join-Path $repoRoot "assets\img\posts\$Slug"

$postFiles = @(Get-ChildItem -LiteralPath $postRoot -File -Recurse |
  Where-Object { $_.BaseName -match "^\d{4}-\d{2}-\d{2}-$([regex]::Escape($Slug))$" } |
  Sort-Object FullName)

if ($postFiles.Count -eq 0) {
  Write-Warning "No post file found for slug '$Slug' under _posts."
}

$filesToOpen = @()
$filesToOpen += $postFiles.FullName

if (Test-Path -LiteralPath $mediaFile -PathType Leaf) {
  $filesToOpen += (Resolve-Path -LiteralPath $mediaFile).Path
} else {
  Write-Warning "No media file found at _data/media/$Slug.yml."
}

if (Test-Path -LiteralPath $imgInfoFile -PathType Leaf) {
  $filesToOpen += (Resolve-Path -LiteralPath $imgInfoFile).Path
}

if ($filesToOpen.Count -gt 0) {
  $code = Get-Command code -ErrorAction SilentlyContinue
  if ($code) {
    & $code.Source -r @filesToOpen
  } else {
    foreach ($file in $filesToOpen) {
      Invoke-Item -LiteralPath $file
    }
  }
}

if (Test-Path -LiteralPath $assetDir -PathType Container) {
  $resolvedAssetDir = (Resolve-Path -LiteralPath $assetDir).Path
  Write-Host "Assets: $resolvedAssetDir"

  if (-not $NoExplorer) {
    explorer.exe $resolvedAssetDir
  }
} else {
  Write-Warning "No asset folder found at assets/img/posts/$Slug."
}
