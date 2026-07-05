#Requires -Version 5.1
<#
.SYNOPSIS
Adds image or video media to an existing Jekyll post.

.DESCRIPTION
Imports media into the post's assets/img/posts/<slug> folder, updates media.yml,
adds starter include blocks to the post body, generates derived assets, and runs
the post validator.

.EXAMPLE
.\add-post-media.ps1 -Slug pen-tray -ImportFrom C:\Temp\pen-tray-media

.EXAMPLE
.\add-post-media.ps1 -PostPath _posts\woodworking\2026-02-26-pen-tray.MD -MediaFiles C:\Temp\IMG_1001.HEIC,C:\Temp\clip.MOV
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$PostPath,
    [string]$Slug,
    [string]$ImportFrom,
    [string[]]$MediaFiles,
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
    Write-Host "[add-media] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[add-media] $Message" -ForegroundColor Yellow
}

function ConvertTo-PostSlug {
    param([Parameter(Mandatory = $true)][string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "&", " and "
    $slug = $slug -replace "[^a-z0-9]+", "-"
    return $slug.Trim("-")
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

    $suffix = if ($DefaultValue) { "[Y/n]" } else { "[y/N]" }
    $value = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    return $value.Trim().ToLowerInvariant().StartsWith("y")
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
        $SlugValue = Read-OptionalValue -Prompt "Post slug" -CurrentValue ""
    }

    if ([string]::IsNullOrWhiteSpace($SlugValue)) {
        throw "Provide either -PostPath or -Slug."
    }

    $normalizedSlug = ConvertTo-PostSlug $SlugValue
    $postsRoot = Join-Path $RepoRoot "_posts"
    $matches = @(Get-ChildItem -Path $postsRoot -Filter "*-$normalizedSlug.MD" -File -Recurse)
    if ($matches.Count -eq 0) {
        throw "No post found for slug '$normalizedSlug'."
    }
    if ($matches.Count -gt 1) {
        throw "Multiple posts found for slug '$normalizedSlug': $($matches.FullName -join ', ')"
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

function Get-PostSlugFromPath {
    param([string]$PathValue)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($PathValue)
    if ($name -match "^\d{4}-\d{2}-\d{2}-(.+)$") {
        return $matches[1]
    }

    return $name
}

function Resolve-MediaDir {
    param(
        [string]$FrontMatter,
        [string]$PostSlug
    )

    $mediaSubpath = Get-Scalar -FrontMatter $FrontMatter -Name "media_subpath"
    if ([string]::IsNullOrWhiteSpace($mediaSubpath)) {
        $mediaSubpath = "/assets/img/posts/$PostSlug"
        Write-Warn "Post has no media_subpath; using $mediaSubpath."
    }

    $relative = $mediaSubpath.Trim('"').Trim("'").TrimStart("/") -replace "/", [System.IO.Path]::DirectorySeparatorChar
    return Join-Path $RepoRoot $relative
}

function Get-ImportCandidates {
    param(
        [string]$Folder,
        [string[]]$Files
    )

    $folderCandidates = @(Get-ImportableMedia -Folder $Folder)
    $fileCandidates = @(Get-ImportableMediaFiles -Paths $Files)
    return @($folderCandidates + $fileCandidates |
        Sort-Object FullName -Unique |
        Sort-Object Name)
}

function Copy-MediaToPostFolder {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Candidates,
        [Parameter(Mandatory = $true)][string]$MediaDir
    )

    $copied = @()
    New-Item -Path $MediaDir -ItemType Directory -Force | Out-Null

    foreach ($candidate in $Candidates) {
        $destination = Join-Path $MediaDir $candidate.Name
        if ((Test-Path -LiteralPath $destination) -and -not $Force) {
            Write-Warn "Skipping existing media file: $($candidate.Name). Use -Force to overwrite."
            $copied += Get-Item -LiteralPath $destination
            continue
        }

        if ($PSCmdlet.ShouldProcess($destination, "Import media file")) {
            Copy-Item -LiteralPath $candidate.FullName -Destination $destination -Force:$Force
            $copied += Get-Item -LiteralPath $destination
        }
    }

    return @($copied | Sort-Object Name)
}

function Get-MediaNeedingImageInclude {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Candidates,
        [Parameter(Mandatory = $true)][string]$PostContent
    )

    return @($Candidates |
        Where-Object { @(".avif", ".png", ".jpg", ".jpeg", ".heic") -contains $_.Extension.ToLowerInvariant() } |
        Where-Object {
            $siteName = ConvertTo-SiteImageName -ImageName $_.Name
            $pattern = "img\s*=\s*[""']$([regex]::Escape($siteName))[""']"
            $PostContent -notmatch $pattern
        } |
        Sort-Object Name)
}

function Get-MediaNeedingVideoInclude {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Candidates,
        [Parameter(Mandatory = $true)][string]$PostContent
    )

    return @($Candidates |
        Where-Object { @(".mp4", ".mov") -contains $_.Extension.ToLowerInvariant() } |
        Where-Object {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $master = "stream/$baseName/master.m3u8"
            $pattern = "master\s*=\s*[""']$([regex]::Escape($master))[""']"
            $PostContent -notmatch $pattern
        } |
        Sort-Object Name)
}

function Add-IncludeBlocksToPost {
    param(
        [Parameter(Mandatory = $true)][string]$PostPath,
        [Parameter(Mandatory = $true)][System.IO.FileInfo[]]$ImportedCandidates,
        [Parameter(Mandatory = $true)][string]$PostTitle
    )

    $content = Get-Content -LiteralPath $PostPath -Raw
    $imageCandidates = @(Get-MediaNeedingImageInclude -Candidates $ImportedCandidates -PostContent $content)
    $videoCandidates = @(Get-MediaNeedingVideoInclude -Candidates $ImportedCandidates -PostContent $content)

    $blocks = @()
    $imageBlock = Get-ImportedImageIncludeBlock -ImportedCandidates $imageCandidates -FallbackImage ""
    if (-not [string]::IsNullOrWhiteSpace($imageBlock)) {
        $blocks += $imageBlock
    }

    $videoBlock = Get-ImportedVideoIncludeBlock -ImportedCandidates $videoCandidates -PostTitle $PostTitle
    if (-not [string]::IsNullOrWhiteSpace($videoBlock)) {
        $blocks += $videoBlock.TrimEnd()
    }

    if ($blocks.Count -eq 0) {
        Write-Info "No new include blocks were needed."
        return
    }

    $blockText = ($blocks -join "`r`n`r`n").Trim()
    $materialsPattern = "(?m)^## Materials and Tools\s*$"
    $match = [regex]::Match($content, $materialsPattern)
    if ($match.Success) {
        $updated = $content.Substring(0, $match.Index).TrimEnd() + "`r`n`r`n" + $blockText + "`r`n`r`n" + $content.Substring($match.Index)
    }
    else {
        $updated = $content.TrimEnd() + "`r`n`r`n" + $blockText + "`r`n"
    }

    if ($PSCmdlet.ShouldProcess($PostPath, "Add media include blocks")) {
        Set-Content -LiteralPath $PostPath -Value $updated -Encoding UTF8
        Write-Info "Added starter include block(s) to $PostPath."
    }
}

Push-Location $RepoRoot
try {
    $resolvedPostPath = Resolve-PostPath -PathValue $PostPath -SlugValue $Slug
    if (-not (Test-Path -LiteralPath $resolvedPostPath)) {
        throw "Post path does not exist: $resolvedPostPath"
    }

    if ([string]::IsNullOrWhiteSpace($ImportFrom) -and ($null -eq $MediaFiles -or $MediaFiles.Count -eq 0)) {
        $ImportFrom = Read-OptionalValue -Prompt "Import media from folder" -CurrentValue ""
    }

    $postContent = Get-Content -LiteralPath $resolvedPostPath -Raw
    $frontMatter = Get-FrontMatter -Content $postContent
    if ($null -eq $frontMatter) {
        throw "Front matter block was not found in $resolvedPostPath."
    }

    $postSlug = Get-PostSlugFromPath -PathValue $resolvedPostPath
    $postTitle = Get-Scalar -FrontMatter $frontMatter -Name "title"
    if ([string]::IsNullOrWhiteSpace($postTitle)) {
        $postTitle = $postSlug
    }

    $mediaDir = Resolve-MediaDir -FrontMatter $frontMatter -PostSlug $postSlug
    $importCandidates = @(Get-ImportCandidates -Folder $ImportFrom -Files $MediaFiles)
    if ($importCandidates.Count -eq 0) {
        throw "No importable media found. Supported extensions: HEIC, JPG, JPEG, PNG, AVIF, MP4, MOV."
    }

    if (-not $PSBoundParameters.ContainsKey("GenerateDerivatives")) {
        $GenerateDerivatives = Read-YesNo -Prompt "Generate derived image/video assets for imported media now?" -DefaultValue $true
    }

    $imported = @(Copy-MediaToPostFolder -Candidates $importCandidates -MediaDir $mediaDir)
    if ($imported.Count -eq 0) {
        Write-Warn "No media files were imported."
        return
    }

    Write-Info "Imported or reused $($imported.Count) media file(s) in $mediaDir."

    $manifestPath = Join-Path $mediaDir "media.yml"
    $manifestAdded = @(Add-MediaManifestEntries -ManifestPath $manifestPath -ImportedCandidates $imported)
    if ($manifestAdded.Count -gt 0) {
        Write-Info "Updated $manifestPath with $($manifestAdded.Count) new media item(s)."
    }
    else {
        Write-Info "media.yml already had entries for the imported media."
    }

    Add-IncludeBlocksToPost -PostPath $resolvedPostPath -ImportedCandidates $imported -PostTitle $postTitle

    if ($GenerateDerivatives) {
        if (Test-HasImportedImage -ImportedCandidates $imported) {
            try {
                Invoke-ScopedDerivativeGeneration -RepoRoot $RepoRoot -MediaPath $mediaDir
            }
            catch {
                Write-Warn "Derived image generation failed: $($_.Exception.Message)"
            }
        }

        if (Test-HasImportedVideo -ImportedCandidates $imported) {
            try {
                Invoke-ScopedHlsGeneration -RepoRoot $RepoRoot -PostSlug $postSlug
            }
            catch {
                Write-Warn "HLS video generation failed: $($_.Exception.Message)"
            }
        }
    }

    if (-not $NoValidate) {
        $validatorPath = Join-Path $RepoRoot "test-post.ps1"
        if (Test-Path -LiteralPath $validatorPath) {
            & $validatorPath -PostPath $resolvedPostPath
        }
        else {
            Write-Warn "test-post.ps1 was not found; skipping validation."
        }
    }
}
finally {
    Pop-Location
}
