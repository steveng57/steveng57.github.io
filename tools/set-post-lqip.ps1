[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$PostPath,

  [int]$Width = 32,

  [ValidateRange(1,100)]
  [int]$Quality = 35
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Newline([string]$text) {
  if ($text.Contains("`r`n")) { return "`r`n" }
  return "`n"
}

function Unquote([string]$value) {
  $v = $value.Trim()
  if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
    return $v.Substring(1, $v.Length - 2)
  }
  return $v
}

function Resolve-ImageFilePath {
  param(
    [string]$repoRoot,
    [string]$mediaSubpath,
    [string]$imagePath
  )
  if ([string]::IsNullOrWhiteSpace($imagePath)) {
    throw 'Front matter does not contain image.path (or image)'
  }

  $imagePath = $imagePath.Trim()

  if ($imagePath -match '^https?:') {
    throw "image.path appears to be a URL; cannot generate LQIP from remote source: $imagePath"
  }

  $mediaDir = $null
  if (-not [string]::IsNullOrWhiteSpace($mediaSubpath)) {
    $mediaDir = Join-Path $repoRoot ($mediaSubpath.Trim('/').Replace('/', [IO.Path]::DirectorySeparatorChar))
  }

  # Common patterns in this repo:
  # - image.path: /thumbnails/foo.avif   + media_subpath: /assets/img/posts/bar
  # - image.path: /assets/img/posts/bar/thumbnails/foo.avif
  # - image.path: foo.avif (relative to media_subpath)

  if ($imagePath.StartsWith('/assets/', [StringComparison]::OrdinalIgnoreCase)) {
    $candidate = Join-Path $repoRoot ($imagePath.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar))
    return (Resolve-Path -LiteralPath $candidate).Path
  }

  if ($mediaDir) {
    if ($imagePath.StartsWith('/')) {
      $relative = $imagePath.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
      $candidate = Join-Path $mediaDir $relative
      if (Test-Path -LiteralPath $candidate) {
        return (Resolve-Path -LiteralPath $candidate).Path
      }

      # If someone put /thumbnails/foo but the file lives under mediaDir\thumbnails\foo
      if ($imagePath -match '^/thumbnails?/') {
        $candidate2 = Join-Path $mediaDir ($imagePath.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar))
        if (Test-Path -LiteralPath $candidate2) {
          return (Resolve-Path -LiteralPath $candidate2).Path
        }
      }

      throw "Could not find image file. Tried: $candidate"
    }

    $candidate = Join-Path $mediaDir ($imagePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }

    throw "Could not find image file. Tried: $candidate"
  }

  throw 'media_subpath missing; cannot resolve a relative image.path into a file'
}

function Get-PostFrontMatter([string]$raw) {
  $nl = Get-Newline $raw
  $lines = $raw -split "\r?\n"

  $fmStart = -1
  $fmEnd = -1

  $firstNonEmpty = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if (-not [string]::IsNullOrWhiteSpace($lines[$i])) {
      $firstNonEmpty = $i
      break
    }
  }

  if ($firstNonEmpty -lt 0) {
    throw 'File is empty'
  }

  $firstLine = $lines[$firstNonEmpty].Trim().TrimStart([char]0xFEFF)
  if ($firstLine -ne '---') {
    throw 'Expected YAML front matter starting at the first non-empty line (---)'
  }

  $fmStart = $firstNonEmpty

  for ($i = $fmStart + 1; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Trim().TrimStart([char]0xFEFF) -eq '---') {
      $fmEnd = $i
      break
    }
  }

  if ($fmEnd -lt 0) {
    throw 'Could not find YAML front matter closing delimiter (---)'
  }

  return [pscustomobject]@{
    Newline = $nl
    Lines = $lines
    FrontMatterStart = $fmStart
    FrontMatterEnd = $fmEnd
  }
}

function Get-FrontMatterValue([string[]]$fmLines, [string]$key) {
  foreach ($line in $fmLines) {
    if ($line -match "^\s*${key}\s*:\s*(.+?)\s*$") {
      return (Unquote $Matches[1])
    }
  }
  return $null
}

function Get-ImagePathFromFrontMatter([string[]]$fmLines) {
  $imageLineIndex = -1
  for ($i = 0; $i -lt $fmLines.Length; $i++) {
    if ($fmLines[$i] -match '^\s*image\s*:\s*$') {
      $imageLineIndex = $i
      break
    }

    if ($fmLines[$i] -match '^\s*image\s*:\s*(.+?)\s*$') {
      return [pscustomobject]@{
        Kind = 'scalar'
        LineIndex = $i
        Value = (Unquote $Matches[1])
      }
    }
  }

  if ($imageLineIndex -lt 0) {
    return $null
  }

  $blockEnd = $fmLines.Length
  for ($j = $imageLineIndex + 1; $j -lt $fmLines.Length; $j++) {
    $line = $fmLines[$j]
    if ($line -match '^\S' -and -not [string]::IsNullOrWhiteSpace($line)) {
      $blockEnd = $j
      break
    }
  }

  $pathValue = $null
  for ($j = $imageLineIndex + 1; $j -lt $blockEnd; $j++) {
    if ($fmLines[$j] -match '^\s+path\s*:\s*(.+?)\s*$') {
      $pathValue = (Unquote $Matches[1])
      break
    }
  }

  return [pscustomobject]@{
    Kind = 'map'
    LineIndex = $imageLineIndex
    BlockEnd = $blockEnd
    Path = $pathValue
  }
}

function Set-ImageLqipInFrontMatter {
  param(
    [string[]]$allLines,
    [int]$fmStart,
    [int]$fmEnd,
    [string]$dataUri
  )
  $fmLines = $allLines[($fmStart + 1)..($fmEnd - 1)]

  $imageInfo = Get-ImagePathFromFrontMatter $fmLines
  if (-not $imageInfo) {
    throw 'Front matter does not contain an image entry'
  }

  $dataUriYaml = '"' + ($dataUri -replace '"', '\\"') + '"'

  if ($imageInfo.Kind -eq 'scalar') {
    $idx = $fmStart + 1 + $imageInfo.LineIndex
    $existingLine = $allLines[$idx]
    $prefix = ($existingLine -replace 'image\s*:\s*.+$', 'image:')
    $allLines[$idx] = $prefix
    $indent = '  '
    $insert = @(
      "$indent`path: $([string]::Concat('"', (Unquote ($existingLine -replace '^\s*image\s*:\s*', '')), '"'))",
      "$indent`lqip: $dataUriYaml"
    )

    $before = $allLines[0..$idx]
    $after = $allLines[($idx + 1)..($allLines.Length - 1)]
    return ,@($before + $insert + $after)
  }

  $imgStart = $fmStart + 1 + $imageInfo.LineIndex
  $imgBlockEnd = $fmStart + 1 + $imageInfo.BlockEnd

  $indent = '  '
  for ($i = $imgStart + 1; $i -lt $imgBlockEnd; $i++) {
    if ($allLines[$i] -match '^(\s+)\S') {
      $indent = $Matches[1]
      break
    }
  }

  $lqipLineIndex = -1
  $pathLineIndex = -1
  for ($i = $imgStart + 1; $i -lt $imgBlockEnd; $i++) {
    if ($allLines[$i] -match '^\s+lqip\s*:') {
      $lqipLineIndex = $i
    }
    if ($allLines[$i] -match '^\s+path\s*:') {
      $pathLineIndex = $i
    }
  }

  if ($lqipLineIndex -ge 0) {
    $allLines[$lqipLineIndex] = "$indent`lqip: $dataUriYaml"
    return ,$allLines
  }

  $insertAt = if ($pathLineIndex -ge 0) { $pathLineIndex + 1 } else { $imgStart + 1 }
  $before = $allLines[0..($insertAt - 1)]
  $after = $allLines[$insertAt..($allLines.Length - 1)]
  $insert = @("$indent`lqip: $dataUriYaml")

  return ,@($before + $insert + $after)
}

$resolvedPostPath = (Resolve-Path -LiteralPath $PostPath).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

$raw = Get-Content -Raw -LiteralPath $resolvedPostPath -Encoding utf8
$fm = Get-PostFrontMatter $raw

$hadTrailingNewline = $false
if ($raw.EndsWith("`r`n")) { $hadTrailingNewline = $true }
elseif ($raw.EndsWith("`n")) { $hadTrailingNewline = $true }

$fmLines = $fm.Lines[($fm.FrontMatterStart + 1)..($fm.FrontMatterEnd - 1)]
$mediaSubpath = Get-FrontMatterValue $fmLines 'media_subpath'

$imageInfo = Get-ImagePathFromFrontMatter $fmLines
if (-not $imageInfo) {
  throw 'Front matter does not contain an image entry'
}

$imagePathValue = if ($imageInfo.Kind -eq 'scalar') { $imageInfo.Value } else { $imageInfo.Path }

$inputImagePath = Resolve-ImageFilePath -repoRoot $repoRoot -mediaSubpath $mediaSubpath -imagePath $imagePathValue

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
  throw 'ImageMagick `magick` not found in PATH. Install ImageMagick or ensure magick.exe is available.'
}

$tmpOut = Join-Path ([IO.Path]::GetTempPath()) ("lqip_" + [IO.Path]::GetRandomFileName() + '.avif')
try {
  & magick $inputImagePath -resize ("${Width}x") -strip -quality $Quality $tmpOut
  if ($LASTEXITCODE -ne 0) {
    throw "ImageMagick failed with exit code $LASTEXITCODE"
  }

  $bytes = [IO.File]::ReadAllBytes($tmpOut)
  $b64 = [Convert]::ToBase64String($bytes)
  $dataUri = "data:image/avif;base64,$b64"

  $newLines = Set-ImageLqipInFrontMatter -allLines $fm.Lines -fmStart $fm.FrontMatterStart -fmEnd $fm.FrontMatterEnd -dataUri $dataUri
  $newRaw = [string]::Join($fm.Newline, $newLines)
  if ($hadTrailingNewline -and (-not ($newRaw.EndsWith("`n") -or $newRaw.EndsWith("`r`n")))) {
    $newRaw += $fm.Newline
  }

  $shouldWrite = $PSCmdlet.ShouldProcess($resolvedPostPath, 'Write image.lqip data URI into YAML front matter')
  if ($shouldWrite) {
    Set-Content -LiteralPath $resolvedPostPath -Value $newRaw -Encoding utf8NoBOM
    Write-Host "Updated image.lqip in: $resolvedPostPath" -ForegroundColor Green
  } else {
    Write-Host "WhatIf: would update image.lqip in: $resolvedPostPath" -ForegroundColor Yellow
  }
}
finally {
  if (Test-Path -LiteralPath $tmpOut) {
    Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue
  }
}
