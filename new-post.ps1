#Requires -Version 5.1
<#
.SYNOPSIS
Creates a new Jekyll post and matching media folder.

.DESCRIPTION
Guided helper for this site's post conventions. It creates a markdown file under
`_posts/<top-category>/`, creates `assets/img/posts/<slug>/`, optionally imports
source media, and can run post validation after scaffolding.

.EXAMPLE
.\new-post.ps1

.EXAMPLE
.\new-post.ps1 -Title "Shop Cabinet" -Description "A new storage cabinet." -TopCategory Woodworking -Subcategory Workshop -Tags Woodworking,Workshop -CoverImage IMG_1001.avif -CoverAlt "Finished cabinet" -GenerateDerivatives
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Title,
    [string]$Description,
    [datetime]$Date,
    [string]$Slug,
    [ValidateSet("Woodworking", "Home and Garden")]
    [string]$TopCategory,
    [string]$Subcategory,
    [string[]]$Tags,
    [string]$CoverImage,
    [string]$CoverAlt,
    [string]$ImportFrom,
    [switch]$Favorite,
    [switch]$Pin,
    [string]$Series,
    [switch]$GenerateDerivatives,
    [switch]$NoValidate,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $RepoRoot "post-media.ps1")

function Write-Info {
    param([string]$Message)
    Write-Host "[new-post] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[new-post] $Message" -ForegroundColor Yellow
}

function ConvertTo-PostSlug {
    param([Parameter(Mandatory = $true)][string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "&", " and "
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Could not derive a slug from '$Value'."
    }

    return $slug
}

function Read-RequiredValue {
    param(
        [string]$Prompt,
        [string]$CurrentValue
    )

    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) {
        return $CurrentValue.Trim()
    }

    do {
        $value = Read-Host $Prompt
    } while ([string]::IsNullOrWhiteSpace($value))

    return $value.Trim()
}

function Read-OptionalValue {
    param(
        [string]$Prompt,
        [string]$CurrentValue,
        [string]$DefaultValue = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) {
        return $CurrentValue.Trim()
    }

    if ($DefaultValue -ne "") {
        $value = Read-Host "$Prompt [$DefaultValue]"
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultValue
        }
        return $value.Trim()
    }

    $value = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($value)) {
        return ""
    }

    return $value.Trim()
}

function Read-YesNo {
    param(
        [string]$Prompt,
        [bool]$DefaultValue = $false
    )

    $suffix = "[y/N]"
    if ($DefaultValue) {
        $suffix = "[Y/n]"
    }

    $value = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    return $value.Trim().ToLowerInvariant().StartsWith("y")
}

function Get-ExistingSubcategories {
    param([Parameter(Mandatory = $true)][string]$Category)

    $postsRoot = Join-Path $RepoRoot "_posts"
    if (-not (Test-Path -LiteralPath $postsRoot)) {
        return @()
    }

    $escaped = [regex]::Escape($Category)
    $pattern = "^\s*category:\s*\[\s*$escaped\s*,\s*([^\]]+)\]"

    return Get-ChildItem -Path $postsRoot -Filter "*.MD" -File -Recurse |
        ForEach-Object {
            $match = Select-String -LiteralPath $_.FullName -Pattern $pattern -CaseSensitive:$false | Select-Object -First 1
            if ($match) {
                $match.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'")
            }
        } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
}

function Select-Category {
    param([string]$CurrentValue)

    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) {
        return $CurrentValue
    }

    Write-Host ""
    Write-Host "Top category:"
    Write-Host "  1. Woodworking"
    Write-Host "  2. Home and Garden"
    $choice = Read-Host "Choose 1 or 2 [1]"
    if ($choice -eq "2") {
        return "Home and Garden"
    }

    return "Woodworking"
}

function Select-Subcategory {
    param(
        [string]$Category,
        [string]$CurrentValue
    )

    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) {
        return $CurrentValue.Trim()
    }

    $subcategories = @(Get-ExistingSubcategories -Category $Category)
    if ($subcategories.Count -gt 0) {
        Write-Host ""
        Write-Host "Known subcategories under ${Category}:"
        for ($i = 0; $i -lt $subcategories.Count; $i++) {
            Write-Host ("  {0}. {1}" -f ($i + 1), $subcategories[$i])
        }

        $choice = Read-Host "Choose a number or type a new subcategory"
        if ($choice -match "^\d+$") {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $subcategories.Count) {
                return $subcategories[$index]
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($choice)) {
            return $choice.Trim()
        }
    }

    return Read-RequiredValue -Prompt "Subcategory" -CurrentValue ""
}

function ConvertTo-YamlInlineList {
    param([string[]]$Values)

    $quoted = @($Values |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object {
            $item = $_.Trim().Replace("\", "\\").Replace('"', '\"')
            '"' + $item + '"'
        })

    return "[" + ($quoted -join ", ") + "]"
}

function ConvertTo-YamlScalar {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    return '"' + $Value.Replace("\", "\\").Replace('"', '\"') + '"'
}

function Resolve-CoverImage {
    param(
        [string]$CurrentValue,
        [System.IO.FileInfo[]]$ImportedCandidates
    )

    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) {
        return $CurrentValue.Trim()
    }

    if ($ImportedCandidates.Count -gt 0) {
        $imageCandidates = @($ImportedCandidates | Where-Object { $_.Extension.ToLowerInvariant() -in @(".avif", ".png", ".jpg", ".jpeg", ".heic") })
        if ($imageCandidates.Count -gt 0) {
            Write-Host ""
            Write-Host "Imported image candidates:"
            for ($i = 0; $i -lt $imageCandidates.Count; $i++) {
                Write-Host ("  {0}. {1}" -f ($i + 1), $imageCandidates[$i].Name)
            }

            $choice = Read-Host "Choose cover image number or type a filename [$($imageCandidates[0].Name)]"
            if ([string]::IsNullOrWhiteSpace($choice)) {
                return $imageCandidates[0].Name
            }

            if ($choice -match "^\d+$") {
                $index = [int]$choice - 1
                if ($index -ge 0 -and $index -lt $imageCandidates.Count) {
                    return $imageCandidates[$index].Name
                }
            }

            return $choice.Trim()
        }
    }

    return Read-RequiredValue -Prompt "Cover image filename, relative to the post media folder" -CurrentValue ""
}

Push-Location $RepoRoot
try {
    $Title = Read-RequiredValue -Prompt "Title" -CurrentValue $Title
    if ([string]::IsNullOrWhiteSpace($Slug)) {
        $Slug = ConvertTo-PostSlug $Title
        $Slug = Read-OptionalValue -Prompt "Slug" -CurrentValue "" -DefaultValue $Slug
    }
    else {
        $Slug = ConvertTo-PostSlug $Slug
    }

    if ($PSBoundParameters.ContainsKey("Date")) {
        $postDate = $Date
    }
    else {
        $today = Get-Date
        $dateInput = Read-OptionalValue -Prompt "Post date" -CurrentValue "" -DefaultValue ($today.ToString("yyyy-MM-dd"))
        $postDate = [datetime]::Parse($dateInput)
    }

    $TopCategory = Select-Category -CurrentValue $TopCategory
    $Subcategory = Select-Subcategory -Category $TopCategory -CurrentValue $Subcategory
    $Description = Read-RequiredValue -Prompt "Description" -CurrentValue $Description

    if ($null -eq $Tags -or $Tags.Count -eq 0) {
        $tagInput = Read-OptionalValue -Prompt "Tags, comma-separated" -CurrentValue "" -DefaultValue "$TopCategory, $Subcategory"
        $Tags = @($tagInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    if ([string]::IsNullOrWhiteSpace($ImportFrom)) {
        $ImportFrom = Read-OptionalValue -Prompt "Import media from folder (optional)" -CurrentValue ""
    }

    $importCandidates = @(Get-ImportableMedia -Folder $ImportFrom)
    $CoverSource = Resolve-CoverImage -CurrentValue $CoverImage -ImportedCandidates $importCandidates
    $CoverSource = Resolve-CoverSourceName -CoverValue $CoverSource -ImportedCandidates $importCandidates
    $CoverImage = $CoverSource
    $CoverImage = ConvertTo-SiteImageName -ImageName $CoverImage
    $CoverAlt = Read-RequiredValue -Prompt "Cover alt/caption" -CurrentValue $CoverAlt

    if (-not $PSBoundParameters.ContainsKey("Favorite")) {
        $Favorite = Read-YesNo -Prompt "Mark as favorite?" -DefaultValue $false
    }

    if (-not $PSBoundParameters.ContainsKey("Pin")) {
        $Pin = Read-YesNo -Prompt "Pin this post?" -DefaultValue $false
    }

    if ([string]::IsNullOrWhiteSpace($Series)) {
        $Series = Read-OptionalValue -Prompt "Series name (optional)" -CurrentValue ""
    }

    if ($importCandidates.Count -gt 0 -and -not $PSBoundParameters.ContainsKey("GenerateDerivatives")) {
        $GenerateDerivatives = Read-YesNo -Prompt "Generate derived image/video assets for imported media now?" -DefaultValue $true
    }

    $categoryFolder = ConvertTo-PostSlug $TopCategory
    $postFileName = "{0}-{1}.MD" -f $postDate.ToString("yyyy-MM-dd"), $Slug
    $postDir = Join-Path (Join-Path $RepoRoot "_posts") $categoryFolder
    $postPath = Join-Path $postDir $postFileName
    $mediaDir = Join-Path (Join-Path (Join-Path (Join-Path $RepoRoot "assets") "img") "posts") $Slug

    if ((Test-Path -LiteralPath $postPath) -and -not $Force) {
        throw "Post already exists: $postPath. Use -Force to overwrite."
    }

    if ((Test-Path -LiteralPath $mediaDir) -and -not $Force) {
        Write-Warn "Media folder already exists: $mediaDir"
    }

    $dateWithTime = Get-Date -Date $postDate -Format "yyyy-MM-dd HH:mm:ss zzz"
    $categoryList = ConvertTo-YamlInlineList @($TopCategory, $Subcategory)
    $tagList = ConvertTo-YamlInlineList $Tags
    $favoriteValue = ([bool]$Favorite).ToString().ToLowerInvariant()
    $pinValue = ([bool]$Pin).ToString().ToLowerInvariant()

    $seriesLine = ""
    if (-not [string]::IsNullOrWhiteSpace($Series)) {
        $seriesLine = "series: $(ConvertTo-YamlScalar $Series)`r`n"
    }
    $imageIncludeBlock = Get-ImportedImageIncludeBlock -ImportedCandidates $importCandidates -FallbackImage $CoverImage
    $videoIncludeBlock = Get-ImportedVideoIncludeBlock -ImportedCandidates $importCandidates -PostTitle $Title
    $mediaManifestContent = New-MediaManifestContent -ImportedCandidates $importCandidates -CoverSource $CoverSource

    $content = @"
---
author: sjg
layout: post
title: $(ConvertTo-YamlScalar $Title)
description: $(ConvertTo-YamlScalar $Description)
date: $dateWithTime
last_modified_at: $dateWithTime
category: $categoryList
tags: $tagList
${seriesLine}image:
  path: $CoverImage
  thumb: /thumbnails/$CoverImage
  alt: $(ConvertTo-YamlScalar $CoverAlt)
media_subpath: /assets/img/posts/$Slug
favorite: $favoriteValue
pin: $pinValue
---
## Background

Write the setup here.

## The Build

$imageIncludeBlock

$videoIncludeBlock

## Finished

Write the finished result here.

## Materials and Tools

- Add materials and tools here
{:.sjg-list }
"@

    if ($PSCmdlet.ShouldProcess($postPath, "Create new post scaffold")) {
        New-Item -Path $postDir -ItemType Directory -Force | Out-Null
        New-Item -Path $mediaDir -ItemType Directory -Force | Out-Null

        if ($importCandidates.Count -gt 0) {
            foreach ($candidate in $importCandidates) {
                $destination = Join-Path $mediaDir $candidate.Name
                Copy-Item -LiteralPath $candidate.FullName -Destination $destination -Force:$Force
            }
            Write-Info "Imported $($importCandidates.Count) media file(s) into assets/img/posts/$Slug."

            if (-not [string]::IsNullOrWhiteSpace($mediaManifestContent)) {
                $mediaManifestPath = Join-Path $mediaDir "media.yml"
                Set-Content -LiteralPath $mediaManifestPath -Value $mediaManifestContent -Encoding UTF8
                Write-Info "Created $mediaManifestPath"
            }
        }

        Set-Content -LiteralPath $postPath -Value $content -Encoding UTF8
        Write-Info "Created $postPath"
        Write-Info "Created $mediaDir"

        if ($GenerateDerivatives) {
            if (Test-HasImportedImage -ImportedCandidates $importCandidates) {
                try {
                    Invoke-ScopedDerivativeGeneration -RepoRoot $RepoRoot -MediaPath $mediaDir
                }
                catch {
                    Write-Warn "Derived image generation failed: $($_.Exception.Message)"
                }
            }
            if (Test-HasImportedVideo -ImportedCandidates $importCandidates) {
                try {
                    Invoke-ScopedHlsGeneration -RepoRoot $RepoRoot -PostSlug $Slug
                }
                catch {
                    Write-Warn "HLS video generation failed: $($_.Exception.Message)"
                }
            }
        }

        if (-not $NoValidate) {
            $validatorPath = Join-Path $RepoRoot "test-post.ps1"
            if (Test-Path -LiteralPath $validatorPath) {
                & $validatorPath -PostPath $postPath
            }
            else {
                Write-Warn "test-post.ps1 was not found; skipping validation."
            }
        }
    }
}
finally {
    Pop-Location
}
