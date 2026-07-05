#Requires -Version 5.1

Set-StrictMode -Version Latest

function ConvertTo-BoolValue {
    param($Value)

    if ($null -eq $Value) {
        return $false
    }

    return @('true', 'yes', '1', 'on') -contains $Value.ToString().Trim().ToLowerInvariant()
}

function ConvertTo-YamlString {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    return '"' + ($Value -replace '\\', '\\' -replace '"', '\"') + '"'
}

function ConvertTo-YamlBoolean {
    param([bool]$Value)

    return $Value.ToString().ToLowerInvariant()
}

function ConvertTo-SiteImageName {
    param([Parameter(Mandatory = $true)][string]$ImageName)

    $trimmed = $ImageName.Trim().Trim('"').Trim("'")
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

function Get-PublishedImageName {
    param([Parameter(Mandatory = $true)]$Image)

    if ($Image.PSObject.Properties.Name -contains 'Published' -and -not [string]::IsNullOrWhiteSpace($Image.Published)) {
        return $Image.Published
    }

    return ConvertTo-SiteImageName -ImageName $Image.Source
}

function Get-PublishedVideoName {
    param([Parameter(Mandatory = $true)]$Video)

    if ($Video.PSObject.Properties.Name -contains 'Published' -and -not [string]::IsNullOrWhiteSpace($Video.Published)) {
        return $Video.Published
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Video.Source)
    return "stream/$baseName/master.m3u8"
}

function Get-MediaDataDirectory {
    param([string]$RepoRoot = (Get-Location).Path)

    return Join-Path (Join-Path $RepoRoot "_data") "media"
}

function Get-MediaManifestPath {
    param(
        [Parameter(Mandatory = $true)][string]$Slug,
        [string]$RepoRoot = (Get-Location).Path
    )

    return Join-Path (Get-MediaDataDirectory -RepoRoot $RepoRoot) "$Slug.yml"
}

function Read-MediaManifestFile {
    param([Parameter(Mandatory = $true)][string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return $null
    }

    $manifest = [ordered]@{
        Cover  = ""
        Images = @()
        Videos = @()
    }
    $current = $null
    $section = ""
    $currentKey = ""

    foreach ($line in Get-Content -LiteralPath $ManifestPath) {
        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -match '^\s*cover:\s*(.*?)\s*$') {
            $manifest.Cover = $matches[1].Trim().Trim('"').Trim("'")
            continue
        }

        if ($line -match '^\s*images:\s*$') {
            if ($current) {
                if ($section -eq "images") { $manifest.Images += [pscustomobject]$current }
                elseif ($section -eq "videos") { $manifest.Videos += [pscustomobject]$current }
            }
            $section = "images"
            $current = $null
            $currentKey = ""
            continue
        }

        if ($line -match '^\s*videos:\s*$') {
            if ($current) {
                if ($section -eq "images") { $manifest.Images += [pscustomobject]$current }
                elseif ($section -eq "videos") { $manifest.Videos += [pscustomobject]$current }
            }
            $section = "videos"
            $current = $null
            $currentKey = ""
            continue
        }

        if ($section -eq "images" -and $line -match '^\s*-\s*source:\s*(.+?)\s*$') {
            if ($current) {
                $manifest.Images += [pscustomobject]$current
            }

            $current = [ordered]@{
                Source    = $matches[1].Trim().Trim('"').Trim("'")
                Published = ""
                Include   = $false
                Gallery   = $false
                Thumbnail = $false
                Caption   = ""
            }
            $currentKey = ""
            continue
        }

        if ($section -eq "videos" -and $line -match '^\s*-\s*source:\s*(.+?)\s*$') {
            if ($current) {
                $manifest.Videos += [pscustomobject]$current
            }

            $current = [ordered]@{
                Source    = $matches[1].Trim().Trim('"').Trim("'")
                Published = ""
                Poster    = ""
                Include   = $false
                Caption   = ""
            }
            $currentKey = ""
            continue
        }

        if ($section -eq "images" -and $line -match '^\s{2}["'']?(.+?)["'']?:\s*$') {
            if ($current) {
                $manifest.Images += [pscustomobject]$current
            }

            $currentKey = $matches[1].Trim().Trim('"').Trim("'")
            $current = [ordered]@{
                Source    = ""
                Published = $currentKey
                Include   = $false
                Gallery   = $false
                Thumbnail = $false
                Caption   = ""
            }
            continue
        }

        if ($section -eq "videos" -and $line -match '^\s{2}["'']?(.+?)["'']?:\s*$') {
            if ($current) {
                $manifest.Videos += [pscustomobject]$current
            }

            $currentKey = $matches[1].Trim().Trim('"').Trim("'")
            $current = [ordered]@{
                Source    = ""
                Published = $currentKey
                Poster    = ""
                Include   = $false
                Caption   = ""
            }
            continue
        }

        if ($current -and $line -match '^\s*(source|published|poster|include|gallery|thumbnail|caption):\s*(.*?)\s*$') {
            $key = $matches[1].ToLowerInvariant()
            $value = $matches[2].Trim().Trim('"').Trim("'")
            switch ($key) {
                'source' { $current.Source = $value }
                'published' { $current.Published = $value }
                'poster' { $current.Poster = $value }
                'include' { $current.Include = ConvertTo-BoolValue $value }
                'gallery' { $current.Gallery = ConvertTo-BoolValue $value }
                'thumbnail' { $current.Thumbnail = ConvertTo-BoolValue $value }
                'caption' { $current.Caption = $value }
            }
        }
    }

    if ($current) {
        if ($section -eq "images") {
            $manifest.Images += [pscustomobject]$current
        }
        elseif ($section -eq "videos") {
            $manifest.Videos += [pscustomobject]$current
        }
    }

    return [pscustomobject]$manifest
}

function Read-MediaManifestForFolder {
    param(
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$Folder,
        [string]$RepoRoot = (Get-Location).Path
    )

    $dataManifestPath = Get-MediaManifestPath -Slug $Folder.Name -RepoRoot $RepoRoot
    if (Test-Path -LiteralPath $dataManifestPath) {
        return Read-MediaManifestFile -ManifestPath $dataManifestPath
    }

    $legacyManifestPath = Join-Path -Path $Folder.FullName -ChildPath "media.yml"
    return Read-MediaManifestFile -ManifestPath $legacyManifestPath
}

function ConvertTo-MediaManifestContent {
    param(
        [string]$Cover,
        [object[]]$Images,
        [object[]]$Videos
    )

    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($Cover)) {
        $lines += "cover: $(ConvertTo-YamlString $Cover)"
        $lines += ""
    }

    $lines += "images:"
    foreach ($image in @($Images)) {
        $published = Get-PublishedImageName -Image $image
        $lines += "  $(ConvertTo-YamlString $published):"
        $lines += "    source: $(ConvertTo-YamlString $image.Source)"
        $lines += "    include: $(ConvertTo-YamlBoolean ([bool]$image.Include))"
        $lines += "    gallery: $(ConvertTo-YamlBoolean ([bool]$image.Gallery))"
        $lines += "    thumbnail: $(ConvertTo-YamlBoolean ([bool]$image.Thumbnail))"
        $lines += "    caption: $(ConvertTo-YamlString $image.Caption)"
        $lines += ""
    }

    if (@($Videos).Count -gt 0) {
        $lines += "videos:"
        foreach ($video in @($Videos)) {
            $published = Get-PublishedVideoName -Video $video
            $lines += "  $(ConvertTo-YamlString $published):"
            $lines += "    source: $(ConvertTo-YamlString $video.Source)"
            $lines += "    poster: $(ConvertTo-YamlString $video.Poster)"
            $lines += "    include: $(ConvertTo-YamlBoolean ([bool]$video.Include))"
            $lines += "    caption: $(ConvertTo-YamlString $video.Caption)"
            $lines += ""
        }
    }

    return ($lines -join "`r`n").TrimEnd()
}

function Write-MediaManifestFile {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)]$Manifest
    )

    $directory = Split-Path -Parent $ManifestPath
    New-Item -Path $directory -ItemType Directory -Force | Out-Null
    $content = ConvertTo-MediaManifestContent -Cover $Manifest.Cover -Images $Manifest.Images -Videos $Manifest.Videos
    Set-Content -LiteralPath $ManifestPath -Value $content -Encoding UTF8
}
