#Requires -Version 5.1

Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "media-manifest.ps1")

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
            $lines += "{% include figure.html img=`"$imageName`" %}`r`n`r`n{% include clear-float.html %}"
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

function Test-ObjectProperty {
    param(
        $InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return (
        $null -ne $InputObject -and
        $null -ne $InputObject.PSObject -and
        @($InputObject.PSObject.Properties | Where-Object { $_.Name -eq $Name }).Count -gt 0
    )
}

function Get-VideoOrientation {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$Video)

    if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
        return ""
    }

    try {
        $json = & ffprobe -v error -select_streams v:0 -show_entries "stream=width,height:stream_tags=rotate:stream_side_data=rotation" -of json $Video.FullName
        if ($LASTEXITCODE -ne 0) {
            return ""
        }

        $info = $json | ConvertFrom-Json
        $stream = $info.streams | Select-Object -First 1
        if (-not $stream) {
            return ""
        }

        $width = if (Test-ObjectProperty -InputObject $stream -Name "width") { [int]$stream.width } else { 0 }
        $height = if (Test-ObjectProperty -InputObject $stream -Name "height") { [int]$stream.height } else { 0 }
        $rotation = 0
        if ((Test-ObjectProperty -InputObject $stream -Name "tags") -and
            (Test-ObjectProperty -InputObject $stream.tags -Name "rotate")) {
            $rotation = [int]$stream.tags.rotate
        }
        elseif (Test-ObjectProperty -InputObject $stream -Name "side_data_list") {
            foreach ($sideData in @($stream.side_data_list)) {
                if (Test-ObjectProperty -InputObject $sideData -Name "rotation") {
                    $rotation = [int]$sideData.rotation
                    break
                }
            }
        }

        if ([Math]::Abs($rotation) % 180 -eq 90) {
            $temp = $width
            $width = $height
            $height = $temp
        }

        if ($width -gt 0 -and $height -gt $width) {
            return "portrait"
        }

        if ($width -gt 0 -and $height -gt 0) {
            return "landscape"
        }
    }
    catch {
        return ""
    }

    return ""
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
        $orientation = Get-VideoOrientation -Video $video
        $orientationLine = if (-not [string]::IsNullOrWhiteSpace($orientation)) { "  orientation=`"$orientation`"`r`n" } else { "" }
        $blocks += @"
{% include embed/video-hls.html
  id="$playerId"
  master="stream/$baseName/master.m3u8"
$mp4Line  poster="stream/$baseName/poster.avif"
${orientationLine}  title="$(($PostTitle).Replace('"', '&quot;'))"
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
    $images = @()
    $videos = @()
    if ($imageFiles.Count -gt 0) {
        foreach ($image in $imageFiles) {
            $isCover = ([System.IO.Path]::GetFileNameWithoutExtension($image.Name) -eq $coverBase)
            $publishedName = ConvertTo-SiteImageName -ImageName $image.Name
            $images += [pscustomobject]@{
                Source    = $image.Name
                Published = $publishedName
                Include   = $true
                Gallery   = $true
                Thumbnail = $isCover
                Caption   = ""
            }
        }
    }

    if ($videoFiles.Count -gt 0) {
        foreach ($video in $videoFiles) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($video.Name)
            $videos += [pscustomobject]@{
                Source    = $video.Name
                Published = "stream/$baseName/master.m3u8"
                Poster    = "stream/$baseName/poster.avif"
                Include   = $true
                Caption   = ""
            }
        }
    }

    return ConvertTo-MediaManifestContent -Cover $CoverSource -Images $images -Videos $videos
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

    $manifest = Read-MediaManifestFile -ManifestPath $ManifestPath
    if (-not $manifest) {
        return @()
    }

    return @(($manifest.Images + $manifest.Videos) |
        ForEach-Object { $_.Source } |
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

    $manifest = Read-MediaManifestFile -ManifestPath $ManifestPath
    if (-not $manifest) {
        $manifest = [pscustomobject]@{
            Cover  = $CoverSource
            Images = @()
            Videos = @()
        }
    }

    if ([string]::IsNullOrWhiteSpace($manifest.Cover)) {
        $manifest.Cover = $CoverSource
    }

    $existingSources = @($manifest.Images + $manifest.Videos |
        ForEach-Object { $_.Source } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $newItems = @($ImportedCandidates | Where-Object { $existingSources -notcontains $_.Name })
    if ($newItems.Count -eq 0) {
        return @()
    }

    if ([string]::IsNullOrWhiteSpace($manifest.Cover)) {
        $firstImage = @($newItems | Where-Object { @(".avif", ".png", ".jpg", ".jpeg", ".heic") -contains $_.Extension.ToLowerInvariant() } | Select-Object -First 1)
        if ($firstImage.Count -gt 0) {
            $manifest.Cover = $firstImage[0].Name
        }
    }

    foreach ($item in $newItems) {
        if (@(".avif", ".png", ".jpg", ".jpeg", ".heic") -contains $item.Extension.ToLowerInvariant()) {
            $manifest.Images += [pscustomobject]@{
                Source    = $item.Name
                Published = ConvertTo-SiteImageName -ImageName $item.Name
                Include   = $true
                Gallery   = $true
                Thumbnail = $false
                Caption   = ""
            }
        }
        elseif (@(".mp4", ".mov") -contains $item.Extension.ToLowerInvariant()) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($item.Name)
            $manifest.Videos += [pscustomobject]@{
                Source    = $item.Name
                Published = "stream/$baseName/master.m3u8"
                Poster    = "stream/$baseName/poster.avif"
                Include   = $true
                Caption   = ""
            }
        }
    }

    Write-MediaManifestFile -ManifestPath $ManifestPath -Manifest $manifest

    return $newItems
}
