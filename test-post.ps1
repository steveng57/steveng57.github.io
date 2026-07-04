#Requires -Version 5.1
<#
.SYNOPSIS
Validates a Jekyll post against this site's post and media conventions.

.EXAMPLE
.\test-post.ps1 -PostPath _posts\woodworking\2026-02-26-pen-tray.MD

.EXAMPLE
.\test-post.ps1 -Slug pen-tray
#>

[CmdletBinding()]
param(
    [string]$PostPath,
    [string]$Slug,
    [switch]$BuildCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ErrorCount = 0
$script:WarningCount = 0

function Write-CheckError {
    param([string]$Message)
    $script:ErrorCount++
    Write-Host "[post-check] ERROR: $Message" -ForegroundColor Red
}

function Write-CheckWarning {
    param([string]$Message)
    $script:WarningCount++
    Write-Host "[post-check] WARN: $Message" -ForegroundColor Yellow
}

function Write-CheckOk {
    param([string]$Message)
    Write-Host "[post-check] OK: $Message" -ForegroundColor Green
}

function ConvertTo-PostSlug {
    param([Parameter(Mandatory = $true)][string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "&", " and "
    $slug = $slug -replace "[^a-z0-9]+", "-"
    return $slug.Trim("-")
}

function Resolve-PostPath {
    param(
        [string]$PathValue,
        [string]$SlugValue
    )

    if (-not [string]::IsNullOrWhiteSpace($PathValue)) {
        if ([System.IO.Path]::IsPathRooted($PathValue)) {
            return $PathValue
        }
        return Join-Path $RepoRoot $PathValue
    }

    if ([string]::IsNullOrWhiteSpace($SlugValue)) {
        throw "Provide either -PostPath or -Slug."
    }

    $postsRoot = Join-Path $RepoRoot "_posts"
    $matches = @(Get-ChildItem -Path $postsRoot -Filter "*-$SlugValue.MD" -File -Recurse)
    if ($matches.Count -eq 0) {
        throw "No post found for slug '$SlugValue'."
    }
    if ($matches.Count -gt 1) {
        throw "Multiple posts found for slug '$SlugValue': $($matches.FullName -join ', ')"
    }

    return $matches[0].FullName
}

function Get-FrontMatter {
    param([string]$Content)

    $match = [regex]::Match($Content, "(?s)\A---\s*\r?\n(.*?)\r?\n---")
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value
}

function Get-Scalar {
    param(
        [string]$FrontMatter,
        [string]$Name
    )

    $match = [regex]::Match($FrontMatter, "(?m)^\s*$([regex]::Escape($Name)):\s*(.*?)\s*$")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
    }

    return $null
}

function Get-InlineList {
    param(
        [string]$FrontMatter,
        [string]$Name
    )

    $value = Get-Scalar -FrontMatter $FrontMatter -Name $Name
    if ([string]::IsNullOrWhiteSpace($value)) {
        return @()
    }

    $match = [regex]::Match($value, "^\[(.*)\]$")
    if (-not $match.Success) {
        return @()
    }

    return @($match.Groups[1].Value -split "," | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ })
}

function Get-ImageField {
    param(
        [string]$FrontMatter,
        [string]$Name
    )

    $match = [regex]::Match($FrontMatter, "(?ms)^image:\s*\r?\n(.*?)(?=^\S|\z)")
    if (-not $match.Success) {
        return $null
    }

    $block = $match.Groups[1].Value
    $field = [regex]::Match($block, "(?m)^\s+$([regex]::Escape($Name)):\s*(.*?)\s*$")
    if ($field.Success) {
        return $field.Groups[1].Value.Trim().Trim('"').Trim("'")
    }

    return $null
}

function Get-PostSlugFromPath {
    param([string]$PathValue)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($PathValue)
    if ($name -match "^\d{4}-\d{2}-\d{2}-(.+)$") {
        return $matches[1]
    }

    return $name
}

function Test-RelativeMediaFile {
    param(
        [string]$MediaDir,
        [string]$Reference,
        [string]$Context
    )

    if ([string]::IsNullOrWhiteSpace($Reference)) {
        Write-CheckError "$Context is empty."
        return
    }

    if ($Reference -match "^[a-z]+://") {
        Write-CheckOk "$Context is an external URL."
        return
    }

    $pathPart = $Reference
    if ($pathPart.StartsWith("/")) {
        $pathPart = $pathPart.TrimStart("/")
        if ($pathPart.StartsWith("assets/img/posts/")) {
            $candidate = Join-Path $RepoRoot ($pathPart -replace "/", [System.IO.Path]::DirectorySeparatorChar)
        }
        else {
            $candidate = Join-Path $MediaDir ($pathPart -replace "/", [System.IO.Path]::DirectorySeparatorChar)
        }
    }
    else {
        $decoded = [System.Uri]::UnescapeDataString($pathPart)
        $candidate = Join-Path $MediaDir ($decoded -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    }

    if (Test-Path -LiteralPath $candidate) {
        Write-CheckOk "$Context exists: $Reference"
    }
    else {
        Write-CheckError "$Context is missing: $Reference"
    }
}

function Test-IncludeReferences {
    param(
        [string]$Content,
        [string]$MediaDir
    )

    $includeMatches = [regex]::Matches($Content, "{%\s*include\s+(html-side\.html|html-sxs\.html|embed/video-hls\.html)\s+(.*?)%}", "Singleline")
    foreach ($include in $includeMatches) {
        $includeName = $include.Groups[1].Value
        $args = $include.Groups[2].Value

        foreach ($argName in @("img", "img1", "img2", "poster", "mp4")) {
            $pattern = "(?:^|\s)$argName\s*=\s*[""']([^""']+)[""']"
            foreach ($argMatch in [regex]::Matches($args, $pattern)) {
                Test-RelativeMediaFile -MediaDir $MediaDir -Reference $argMatch.Groups[1].Value -Context "$includeName $argName"
            }
        }

        foreach ($argName in @("master")) {
            $pattern = "(?:^|\s)$argName\s*=\s*[""']([^""']+)[""']"
            foreach ($argMatch in [regex]::Matches($args, $pattern)) {
                Test-RelativeMediaFile -MediaDir $MediaDir -Reference $argMatch.Groups[1].Value -Context "$includeName $argName"
            }
        }
    }
}

function Test-MediaManifest {
    param([string]$MediaDir)

    $manifestPath = Join-Path $MediaDir "media.yml"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-CheckWarning "No media.yml found; using legacy media behavior."
        return
    }

    Write-CheckOk "media.yml exists."
    foreach ($line in Get-Content -LiteralPath $manifestPath) {
        if ($line -match '^\s*-\s*source:\s*(.+?)\s*$') {
            $source = $matches[1].Trim().Trim('"').Trim("'")
            $sourcePath = Join-Path $MediaDir $source
            if (Test-Path -LiteralPath $sourcePath) {
                Write-CheckOk "media.yml source exists: $source"
            }
            else {
                Write-CheckError "media.yml source is missing: $source"
            }
        }
    }
}

function Test-JekyllBuild {
    Push-Location $RepoRoot
    try {
        Write-Host "[post-check] Running bundle exec jekyll build..." -ForegroundColor Cyan
        & bundle exec jekyll build
        if ($LASTEXITCODE -ne 0) {
            Write-CheckError "Jekyll build failed with exit code $LASTEXITCODE."
        }
        else {
            Write-CheckOk "Jekyll build passed."
        }
    }
    finally {
        Pop-Location
    }
}

$resolvedPostPath = Resolve-PostPath -PathValue $PostPath -SlugValue $Slug
if (-not (Test-Path -LiteralPath $resolvedPostPath)) {
    throw "Post path does not exist: $resolvedPostPath"
}

$content = Get-Content -LiteralPath $resolvedPostPath -Raw
$frontMatter = Get-FrontMatter -Content $content
if ($null -eq $frontMatter) {
    Write-CheckError "Front matter block was not found."
    exit 1
}

$postSlug = Get-PostSlugFromPath -PathValue $resolvedPostPath
$title = Get-Scalar -FrontMatter $frontMatter -Name "title"
$description = Get-Scalar -FrontMatter $frontMatter -Name "description"
$date = Get-Scalar -FrontMatter $frontMatter -Name "date"
$mediaSubpath = Get-Scalar -FrontMatter $frontMatter -Name "media_subpath"
$categories = @(Get-InlineList -FrontMatter $frontMatter -Name "category")
$tags = @(Get-InlineList -FrontMatter $frontMatter -Name "tags")
$imagePath = Get-ImageField -FrontMatter $frontMatter -Name "path"
$imageThumb = Get-ImageField -FrontMatter $frontMatter -Name "thumb"
$imageAlt = Get-ImageField -FrontMatter $frontMatter -Name "alt"

foreach ($required in @(
        @{ Name = "title"; Value = $title },
        @{ Name = "description"; Value = $description },
        @{ Name = "date"; Value = $date },
        @{ Name = "media_subpath"; Value = $mediaSubpath },
        @{ Name = "image.path"; Value = $imagePath },
        @{ Name = "image.thumb"; Value = $imageThumb },
        @{ Name = "image.alt"; Value = $imageAlt }
    )) {
    if ([string]::IsNullOrWhiteSpace($required.Value)) {
        Write-CheckError "Missing required front matter: $($required.Name)"
    }
    else {
        Write-CheckOk "Found $($required.Name)."
    }
}

if ($categories.Count -lt 2) {
    Write-CheckError "category should be an inline hierarchy like [Woodworking, Home Decor]."
}
else {
    Write-CheckOk "Category path: $($categories -join ' > ')"
}

if ($tags.Count -eq 0) {
    Write-CheckWarning "No inline tags found. If this post uses multiline tags, consider normalizing it for the wizard workflow."
}
else {
    Write-CheckOk "Found $($tags.Count) tag(s)."
}

if (-not [string]::IsNullOrWhiteSpace($mediaSubpath)) {
    $normalizedMediaSubpath = $mediaSubpath.Trim('"').Trim("'").TrimEnd("/")
    $expectedMediaSubpath = "/assets/img/posts/$postSlug"
    if ($normalizedMediaSubpath -ne $expectedMediaSubpath) {
        Write-CheckWarning "media_subpath is '$mediaSubpath'; expected '$expectedMediaSubpath' based on filename."
    }

    $mediaRelative = $normalizedMediaSubpath.TrimStart("/") -replace "/", [System.IO.Path]::DirectorySeparatorChar
    $mediaDir = Join-Path $RepoRoot $mediaRelative
    if (Test-Path -LiteralPath $mediaDir) {
        Write-CheckOk "Media folder exists: $normalizedMediaSubpath"
    }
    else {
        Write-CheckError "Media folder is missing: $normalizedMediaSubpath"
    }

    Test-RelativeMediaFile -MediaDir $mediaDir -Reference $imagePath -Context "Cover image"
    Test-RelativeMediaFile -MediaDir $mediaDir -Reference $imageThumb -Context "Cover thumbnail"
    Test-IncludeReferences -Content $content -MediaDir $mediaDir
    Test-MediaManifest -MediaDir $mediaDir
}

$iconPath = Join-Path (Join-Path $RepoRoot "_data") "category_icons.yml"
if ($categories.Count -ge 1 -and (Test-Path -LiteralPath $iconPath)) {
    $iconContent = Get-Content -LiteralPath $iconPath -Raw
    foreach ($category in $categories) {
        $escapedCategory = [regex]::Escape($category)
        if ($iconContent -notmatch "(?m)^(`"$escapedCategory`"|$escapedCategory):\s+") {
            Write-CheckWarning "No category icon configured for '$category'."
        }
    }
}

if ($BuildCheck) {
    Test-JekyllBuild
}

if ($script:ErrorCount -gt 0) {
    Write-Host "[post-check] Completed with $script:ErrorCount error(s) and $script:WarningCount warning(s)." -ForegroundColor Red
    exit 1
}

Write-Host "[post-check] Completed with no errors and $script:WarningCount warning(s)." -ForegroundColor Green
