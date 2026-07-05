#Requires -Version 5.1

Set-StrictMode -Version Latest

function ConvertTo-SiteImageName {
    param([Parameter(Mandatory = $true)][string]$ImageName)

    $trimmed = $ImageName.Trim()
    $extension = [System.IO.Path]::GetExtension($trimmed).ToLowerInvariant()
    if ($extension -in @(".heic", ".jpg", ".jpeg", ".png")) {
        $directory = [System.IO.Path]::GetDirectoryName($trimmed)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($trimmed)
        $avifName = "$baseName.avif"
        if ([string]::IsNullOrWhiteSpace($directory)) {
            return $avifName
        }

        return (Join-Path -Path $directory -ChildPath $avifName).Replace('\', '/')
    }

    return $trimmed
}

function ConvertTo-YamlBoolean {
    param([bool]$Value)

    return $Value.ToString().ToLowerInvariant()
}

function Get-ImportableMedia {
    param([string]$Folder)

    if ([string]::IsNullOrWhiteSpace($Folder) -or -not (Test-Path -LiteralPath $Folder)) {
        return @()
    }

    $extensions = @(".jpg", ".jpeg", ".png", ".heic", ".avif", ".mp4", ".mov")
    return @(Get-ChildItem -LiteralPath $Folder -File |
        Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name)
}

function Get-ImportableMediaFiles {
    param([string[]]$Paths)

    if ($null -eq $Paths -or $Paths.Count -eq 0) {
        return @()
    }

    $extensions = @(".jpg", ".jpeg", ".png", ".heic", ".avif", ".mp4", ".mov")
    $files = @()
    foreach ($path in $Paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        if (-not (Test-Path -LiteralPath $path)) {
            throw "Media file does not exist: $path"
        }

        $item = Get-Item -LiteralPath $path
        if ($item.PSIsContainer) {
            throw "Expected a file but got a folder: $path"
        }

        if ($extensions -notcontains $item.Extension.ToLowerInvariant()) {
            throw "Unsupported media extension '$($item.Extension)' for $path"
        }

        $files += $item
    }

    return @($files | Sort-Object Name)
}

function Resolve-CoverSourceName {
    param(
        [Parameter(Mandatory = $true)][string]$CoverValue,
        [System.IO.FileInfo[]]$ImportedCandidates
    )

    $coverBase = [System.IO.Path]::GetFileNameWithoutExtension($CoverValue)
    $masterExtensions = @(".heic", ".jpg", ".jpeg", ".png")
    $matchingMaster = @($ImportedCandidates |
        Where-Object {
            $masterExtensions -contains $_.Extension.ToLowerInvariant() -and
            [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $coverBase
        } |
        Select-Object -First 1)

    if ($matchingMaster.Count -gt 0) {
        return $matchingMaster[0].Name
    }

    return $CoverValue
}

function Get-ImportedImageIncludeBlock {
    param(
        [System.IO.FileInfo[]]$ImportedCandidates,
        [string]$FallbackImage
    )

    $imageExtensions = @(".avif", ".png", ".jpg", ".jpeg", ".heic")
    $imageNames = @($ImportedCandidates |
        Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() } |
        ForEach-Object { ConvertTo-SiteImageName -ImageName $_.Name } |
        Sort-Object -Unique)

    if ($imageNames.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($FallbackImage)) {
        $imageNames = @($FallbackImage)
    }

    $lines = @()
    foreach ($imageName in $imageNames) {
        if (-not [string]::IsNullOrWhiteSpace($imageName)) {
            $lines += "{% include html-side.html img=`"$imageName`" align=`"center-full`" %}"
        }
    }

    return ($lines -join "`r`n`r`n")
}

function ConvertTo-VideoId {
    param([Parameter(Mandatory = $true)][string]$Value)

    $id = [System.IO.Path]::GetFileNameWithoutExtension($Value).ToLowerInvariant()
    $id = $id -replace "[^a-z0-9]+", "-"
    $id = $id.Trim("-")
    if ([string]::IsNullOrWhiteSpace($id)) {
        return "video"
    }

    return "$id-abr"
}

function Get-ImportedVideoIncludeBlock {
    param(
        [System.IO.FileInfo[]]$ImportedCandidates,
        [string]$PostTitle
    )

    $videoFiles = @($ImportedCandidates |
        Where-Object { @(".mp4", ".mov") -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name)

    if ($videoFiles.Count -eq 0) {
        return ""
    }

    $blocks = @()
    foreach ($video in $videoFiles) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($video.Name)
        $playerId = ConvertTo-VideoId -Value $video.Name
        $mp4Line = if ($video.Extension.ToLowerInvariant() -eq ".mp4") { "  mp4=`"$($video.Name)`"`r`n" } else { "  mp4=`"`"`r`n" }
        $blocks += @"
{% include embed/video-hls.html
  id="$playerId"
  master="stream/$baseName/master.m3u8"
$mp4Line  poster="stream/$baseName/poster.avif"
  title="$(($PostTitle).Replace('"', '&quot;'))"
  caption=""
  controls="true"
  muted="false"
  autoplay="false"
  loop="false"
  playsinline="true"
%}
"@
    }

    return ($blocks -join "`r`n")
}

function New-MediaManifestImageEntryLines {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$Image,
        [bool]$Thumbnail
    )

    $publishedName = ConvertTo-SiteImageName -ImageName $Image.Name
    return @(
        "  - source: $($Image.Name)",
        "    published: $publishedName",
        "    include: true",
        "    gallery: true",
        "    thumbnail: $(ConvertTo-YamlBoolean $Thumbnail)",
        "    caption: `"`""
    )
}

function New-MediaManifestVideoEntryLines {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$Video)

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Video.Name)
    return @(
        "  - source: $($Video.Name)",
        "    published: stream/$baseName/master.m3u8",
        "    poster: stream/$baseName/poster.avif",
        "    include: true",
        "    caption: `"`""
    )
}

function New-MediaManifestContent {
    param(
        [System.IO.FileInfo[]]$ImportedCandidates,
        [string]$CoverSource
    )

    $imageExtensions = @(".avif", ".png", ".jpg", ".jpeg", ".heic")
    $imageFiles = @($ImportedCandidates |
        Where-Object { $imageExtensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name)
    $videoFiles = @($ImportedCandidates |
        Where-Object { @(".mp4", ".mov") -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object Name)

    if ($imageFiles.Count -eq 0 -and $videoFiles.Count -eq 0) {
        return ""
    }

    $coverBase = [System.IO.Path]::GetFileNameWithoutExtension($CoverSource)
    $lines = @()
    if ($imageFiles.Count -gt 0) {
        $lines += "cover: $CoverSource"
        $lines += ""
        $lines += "images:"

        foreach ($image in $imageFiles) {
            $isCover = ([System.IO.Path]::GetFileNameWithoutExtension($image.Name) -eq $coverBase)
            $lines += New-MediaManifestImageEntryLines -Image $image -Thumbnail $isCover
            $lines += ""
        }
    }

    if ($videoFiles.Count -gt 0) {
        if ($lines.Count -gt 0 -and $lines[-1] -ne "") {
            $lines += ""
        }

        $lines += "videos:"
        foreach ($video in $videoFiles) {
            $lines += New-MediaManifestVideoEntryLines -Video $video
            $lines += ""
        }
    }

    return ($lines -join "`r`n")
}

function Test-HasImportedVideo {
    param([System.IO.FileInfo[]]$ImportedCandidates)

    return (@($ImportedCandidates | Where-Object { @(".mp4", ".mov") -contains $_.Extension.ToLowerInvariant() }).Count -gt 0)
}

function Test-HasImportedImage {
    param([System.IO.FileInfo[]]$ImportedCandidates)

    return (@($ImportedCandidates | Where-Object { @(".avif", ".png", ".jpg", ".jpeg", ".heic") -contains $_.Extension.ToLowerInvariant() }).Count -gt 0)
}

function Invoke-ScopedDerivativeGeneration {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$MediaPath
    )

    $generatorPath = Join-Path $RepoRoot "gen-derived-avif.ps1"
    if (-not (Test-Path -LiteralPath $generatorPath)) {
        Write-Warning "gen-derived-avif.ps1 was not found; skipping derivative generation."
        return
    }

    Write-Host "[post-media] Generating derived AVIF assets for $MediaPath." -ForegroundColor Cyan
    & $generatorPath -PostPath $MediaPath
}

function Invoke-ScopedHlsGeneration {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PostSlug
    )

    $generatorPath = Join-Path $RepoRoot "gen-hls.ps1"
    if (-not (Test-Path -LiteralPath $generatorPath)) {
        Write-Warning "gen-hls.ps1 was not found; skipping HLS generation."
        return
    }

    Write-Host "[post-media] Generating HLS video assets for $PostSlug." -ForegroundColor Cyan
    & $generatorPath -PostsRoot (Join-Path (Join-Path (Join-Path $RepoRoot "assets") "img") "posts") -TargetPosts $PostSlug
}

function Get-MediaManifestSourceNames {
    param([Parameter(Mandatory = $true)][string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return @()
    }

    return @(Get-Content -LiteralPath $ManifestPath |
        ForEach-Object {
            if ($_ -match '^\s*-\s*source:\s*(.+?)\s*$') {
                $matches[1].Trim().Trim('"').Trim("'")
            }
        } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Add-ManifestSectionEntries {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$SectionName,
        [string[]]$EntryLines
    )

    if ($EntryLines.Count -eq 0) {
        return $Content
    }

    $entryText = ($EntryLines -join "`r`n") + "`r`n"
    $sectionPattern = "(?m)^$([regex]::Escape($SectionName)):\s*$"
    $sectionMatch = [regex]::Match($Content, $sectionPattern)
    if (-not $sectionMatch.Success) {
        $prefix = if ($Content.Trim().Length -eq 0) { "" } else { "`r`n" }
        return $Content.TrimEnd() + $prefix + "${SectionName}:`r`n" + $entryText
    }

    $afterSection = $sectionMatch.Index + $sectionMatch.Length
    $rest = $Content.Substring($afterSection)
    $nextTopLevel = [regex]::Match($rest, "(?m)^\S[^:`r`n]*:\s*")
    if ($nextTopLevel.Success) {
        $insertAt = $afterSection + $nextTopLevel.Index
        return $Content.Substring(0, $insertAt).TrimEnd() + "`r`n" + $entryText + $Content.Substring($insertAt)
    }

    return $Content.TrimEnd() + "`r`n" + $entryText
}

function Add-MediaManifestEntries {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][System.IO.FileInfo[]]$ImportedCandidates,
        [string]$CoverSource = ""
    )

    $existingSources = @(Get-MediaManifestSourceNames -ManifestPath $ManifestPath)
    $newItems = @($ImportedCandidates | Where-Object { $existingSources -notcontains $_.Name })
    if ($newItems.Count -eq 0) {
        return @()
    }

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        if ([string]::IsNullOrWhiteSpace($CoverSource)) {
            $firstImage = @($newItems | Where-Object { @(".avif", ".png", ".jpg", ".jpeg", ".heic") -contains $_.Extension.ToLowerInvariant() } | Select-Object -First 1)
            if ($firstImage.Count -gt 0) {
                $CoverSource = $firstImage[0].Name
            }
        }

        $content = New-MediaManifestContent -ImportedCandidates $newItems -CoverSource $CoverSource
        Set-Content -LiteralPath $ManifestPath -Value $content -Encoding UTF8
        return $newItems
    }

    $content = Get-Content -LiteralPath $ManifestPath -Raw
    $imageLines = @()
    $videoLines = @()
    foreach ($item in $newItems) {
        if (@(".avif", ".png", ".jpg", ".jpeg", ".heic") -contains $item.Extension.ToLowerInvariant()) {
            $imageLines += New-MediaManifestImageEntryLines -Image $item -Thumbnail $false
            $imageLines += ""
        }
        elseif (@(".mp4", ".mov") -contains $item.Extension.ToLowerInvariant()) {
            $videoLines += New-MediaManifestVideoEntryLines -Video $item
            $videoLines += ""
        }
    }

    if ($imageLines.Count -gt 0) {
        $content = Add-ManifestSectionEntries -Content $content -SectionName "images" -EntryLines $imageLines
    }
    if ($videoLines.Count -gt 0) {
        $content = Add-ManifestSectionEntries -Content $content -SectionName "videos" -EntryLines $videoLines
    }
    Set-Content -LiteralPath $ManifestPath -Value $content.TrimEnd() -Encoding UTF8

    return $newItems
}
