<#
.SYNOPSIS
Creates per-post _data/media manifests for legacy post media folders.

.DESCRIPTION
Infers _data/media/<slug>.yml from post front matter, image include tags, and the current
_data/img-info.json file. The script does not read Windows EXIF tags.

By default this is a dry run. Pass -Apply to write _data/media files.
#>

param(
    [string[]]$Slug,
    [string]$PostsRoot = ".\_posts",
    [string]$MediaRoot = ".\assets\img\posts",
    [string]$ImgInfoPath = ".\_data\img-info.json",
    [switch]$Apply,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "media-manifest.ps1")

function Write-Info {
    param([string]$Message)
    Write-Host "[media-manifest] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[media-manifest] WARN: $Message" -ForegroundColor Yellow
}

function ConvertTo-RepoRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetRelativePath($RepoRoot, $Path).Replace('\', '/')
}

function ConvertTo-SitePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return $Path.Trim().Trim('"').Trim("'").TrimStart('/').TrimEnd('/')
}

function ConvertFrom-PostImageName {
    param([Parameter(Mandatory = $true)][string]$ImageName)

    $clean = $ImageName.Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($clean)) {
        return ""
    }

    try {
        return [System.Uri]::UnescapeDataString($clean)
    }
    catch {
        return $clean
    }
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

function ConvertTo-PublishedName {
    param([Parameter(Mandatory = $true)][string]$SourceName)

    $extension = [System.IO.Path]::GetExtension($SourceName).ToLowerInvariant()
    if ($extension -in @(".heic", ".jpg", ".jpeg", ".png")) {
        return ([System.IO.Path]::GetFileNameWithoutExtension($SourceName) + ".avif")
    }

    return $SourceName
}

function Get-FrontMatterValue {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $match = [regex]::Match($Content, "(?m)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Get-ImageFrontMatterValue {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $frontMatter = [regex]::Match($Content, "(?s)^---\s*(.*?)\s*---")
    if (-not $frontMatter.Success) {
        return ""
    }

    $pattern = "(?m)^\s{2}$([regex]::Escape($Name)):\s*(.+?)\s*$"
    $match = [regex]::Match($frontMatter.Groups[1].Value, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Get-PostSlugFromFile {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$PostFile)

    return ($PostFile.BaseName -replace '^\d{4}-\d{2}-\d{2}-', '')
}

function Get-PostImageReferences {
    param([Parameter(Mandatory = $true)][string]$Content)

    $references = New-Object System.Collections.Generic.List[string]
    $includeMatches = [regex]::Matches($Content, '{%\s*include\s+(?:figure|figure-pair)\.html\s+.*?%}')

    foreach ($include in $includeMatches) {
        $attributeMatches = [regex]::Matches($include.Value, '\bimg\d*\s*=\s*["'']([^"'']+)["'']')
        foreach ($attribute in $attributeMatches) {
            $imageName = ConvertFrom-PostImageName $attribute.Groups[1].Value
            if (-not [string]::IsNullOrWhiteSpace($imageName)) {
                $references.Add($imageName)
            }
        }
    }

    return @($references)
}

function Get-ImgInfoEntry {
    param(
        [Parameter(Mandatory = $true)]$ImgInfo,
        [Parameter(Mandatory = $true)][string]$Key
    )

    if ($ImgInfo.PSObject.Properties.Name -contains $Key) {
        return $ImgInfo.PSObject.Properties[$Key].Value
    }

    return $null
}

function Get-FullImageInfoKeys {
    param(
        [Parameter(Mandatory = $true)]$ImgInfo,
        [Parameter(Mandatory = $true)][string]$MediaSitePath
    )

    $prefix = $MediaSitePath.TrimEnd('/') + '/'
    return @($ImgInfo.PSObject.Properties.Name |
        Where-Object {
            $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and
            $_ -notmatch '/(?:thumbnails|thumbnails-2x|tinyfiles)/'
        })
}

function Resolve-FileName {
    param(
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$MediaDir,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $decoded = ConvertFrom-PostImageName $Name
    $files = @(Get-ChildItem -LiteralPath $MediaDir.FullName -File -ErrorAction SilentlyContinue)
    $match = @($files | Where-Object { $_.Name -ieq $decoded } | Select-Object -First 1)
    if ($match.Count -gt 0) {
        return $match[0].Name
    }

    $match = @($files | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1)
    if ($match.Count -gt 0) {
        return $match[0].Name
    }

    return $decoded
}

function Resolve-SourceName {
    param(
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$MediaDir,
        [Parameter(Mandatory = $true)][string]$PublishedName
    )

    $published = Resolve-FileName -MediaDir $MediaDir -Name $PublishedName
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($published)
    $masterExtensions = @(".heic", ".jpg", ".jpeg", ".png")
    $files = @(Get-ChildItem -LiteralPath $MediaDir.FullName -File -ErrorAction SilentlyContinue)

    foreach ($extension in $masterExtensions) {
        $match = @($files |
            Where-Object {
                [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -ieq $baseName -and
                $_.Extension -ieq $extension
            } |
            Select-Object -First 1)

        if ($match.Count -gt 0) {
            return $match[0].Name
        }
    }

    $publishedFile = @($files | Where-Object { $_.Name -ieq $published } | Select-Object -First 1)
    if ($publishedFile.Count -gt 0) {
        return $publishedFile[0].Name
    }

    return $published
}

function Add-ManifestImage {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Specialized.OrderedDictionary]$Images,
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$MediaDir,
        [Parameter(Mandatory = $true)][string]$PublishedName,
        [bool]$Include,
        [bool]$Thumbnail,
        [bool]$Gallery,
        [string]$Caption
    )

    $published = Resolve-FileName -MediaDir $MediaDir -Name $PublishedName
    if ([string]::IsNullOrWhiteSpace($published)) {
        return
    }

    $key = $published.ToLowerInvariant()
    $source = Resolve-SourceName -MediaDir $MediaDir -PublishedName $published
    if (-not $Images.Contains($key)) {
        $sameSource = @($Images.Values | Where-Object { $_.Source -ieq $source } | Select-Object -First 1)
        if ($sameSource.Count -gt 0 -and -not $Include -and -not $Thumbnail) {
            $existingBySource = $sameSource[0]
            $existingBySource.Gallery = [bool]($existingBySource.Gallery -or $Gallery)
            if ([string]::IsNullOrWhiteSpace($existingBySource.Caption) -and -not [string]::IsNullOrWhiteSpace($Caption)) {
                $existingBySource.Caption = $Caption
            }
            return
        }

        $Images[$key] = [ordered]@{
            Source = $source
            Published = $published
            Include = $Include
            Gallery = $Gallery
            Thumbnail = $Thumbnail
            Caption = $Caption
        }
        return
    }

    $existing = $Images[$key]
    $existing.Include = [bool]($existing.Include -or $Include)
    $existing.Gallery = [bool]($existing.Gallery -or $Gallery)
    $existing.Thumbnail = [bool]($existing.Thumbnail -or $Thumbnail)
    if ([string]::IsNullOrWhiteSpace($existing.Caption) -and -not [string]::IsNullOrWhiteSpace($Caption)) {
        $existing.Caption = $Caption
    }
}

function Get-ImageCaption {
    param($Entry)

    if ($null -eq $Entry) {
        return ""
    }

    if ($Entry.PSObject.Properties.Name -contains "title" -and -not [string]::IsNullOrWhiteSpace($Entry.title)) {
        return $Entry.title
    }

    if ($Entry.PSObject.Properties.Name -contains "subject" -and -not [string]::IsNullOrWhiteSpace($Entry.subject)) {
        return $Entry.subject
    }

    return ""
}

function Get-ImageGalleryFlag {
    param($Entry)

    if ($null -eq $Entry -or -not ($Entry.PSObject.Properties.Name -contains "gallery")) {
        return $false
    }

    return [bool]$Entry.gallery
}

function New-MediaManifestContent {
    param(
        [Parameter(Mandatory = $true)][string]$CoverSource,
        [Parameter(Mandatory = $true)][System.Collections.Specialized.OrderedDictionary]$Images
    )

    return ConvertTo-MediaManifestContent -Cover $CoverSource -Images @($Images.Values) -Videos @()
}

if (-not (Test-Path -LiteralPath $PostsRoot)) {
    throw "Posts root '$PostsRoot' was not found."
}

if (-not (Test-Path -LiteralPath $MediaRoot)) {
    throw "Media root '$MediaRoot' was not found."
}

if (-not (Test-Path -LiteralPath $ImgInfoPath)) {
    throw "Image info file '$ImgInfoPath' was not found."
}

$imgInfo = Get-Content -LiteralPath $ImgInfoPath -Raw | ConvertFrom-Json
$postFiles = @(Get-ChildItem -LiteralPath $PostsRoot -Recurse -File -Include *.md, *.MD)
$selectedSlugs = @{}
foreach ($item in @($Slug)) {
    if (-not [string]::IsNullOrWhiteSpace($item)) {
        $selectedSlugs[$item.Trim().ToLowerInvariant()] = $true
    }
}

$processed = 0
$written = 0
$skipped = 0

foreach ($postFile in $postFiles) {
    $content = Get-Content -LiteralPath $postFile.FullName -Raw
    $postSlug = Get-PostSlugFromFile -PostFile $postFile
    $mediaSubpath = Get-FrontMatterValue -Content $content -Name "media_subpath"

    if ([string]::IsNullOrWhiteSpace($mediaSubpath)) {
        continue
    }

    $mediaSitePath = ConvertTo-SitePath $mediaSubpath
    $mediaDirPath = Join-Path -Path $RepoRoot -ChildPath ($mediaSitePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $mediaDirPath)) {
        Write-Warn "Media folder not found for $($postFile.Name): $mediaSubpath"
        continue
    }

    $mediaDir = Get-Item -LiteralPath $mediaDirPath
    $mediaSlug = $mediaDir.Name
    if ($selectedSlugs.Count -gt 0 -and -not $selectedSlugs.ContainsKey($postSlug.ToLowerInvariant()) -and -not $selectedSlugs.ContainsKey($mediaSlug.ToLowerInvariant())) {
        continue
    }

    $manifestPath = Get-MediaManifestPath -Slug $mediaSlug -RepoRoot $RepoRoot
    if ((Test-Path -LiteralPath $manifestPath) -and -not $Force) {
        Write-Info "Skipping $mediaSlug; _data/media manifest already exists. Use -Force to overwrite."
        $skipped++
        continue
    }

    $coverPublished = ConvertFrom-PostImageName (Get-ImageFrontMatterValue -Content $content -Name "path")
    $thumbPublished = ConvertFrom-PostImageName (Get-ImageFrontMatterValue -Content $content -Name "thumb")
    if ($thumbPublished -match '^(?:/)?thumbnails/(.+)$') {
        $thumbPublished = ConvertFrom-PostImageName $matches[1]
    }

    $images = New-Object System.Collections.Specialized.OrderedDictionary

    if (-not [string]::IsNullOrWhiteSpace($coverPublished)) {
        $coverKey = "$mediaSitePath/$coverPublished"
        $coverEntry = Get-ImgInfoEntry -ImgInfo $imgInfo -Key $coverKey
        Add-ManifestImage -Images $images -MediaDir $mediaDir -PublishedName $coverPublished -Include:$false -Thumbnail:$true -Gallery:(Get-ImageGalleryFlag $coverEntry) -Caption:(Get-ImageCaption $coverEntry)
    }

    foreach ($reference in Get-PostImageReferences -Content $content) {
        $published = ConvertFrom-PostImageName $reference
        $metadataKey = "$mediaSitePath/$published"
        $entry = Get-ImgInfoEntry -ImgInfo $imgInfo -Key $metadataKey
        $isThumbnail = -not [string]::IsNullOrWhiteSpace($thumbPublished) -and ($published -ieq $thumbPublished)
        Add-ManifestImage -Images $images -MediaDir $mediaDir -PublishedName $published -Include:$true -Thumbnail:$isThumbnail -Gallery:(Get-ImageGalleryFlag $entry) -Caption:(Get-ImageCaption $entry)
    }

    foreach ($key in Get-FullImageInfoKeys -ImgInfo $imgInfo -MediaSitePath $mediaSitePath) {
        $entry = Get-ImgInfoEntry -ImgInfo $imgInfo -Key $key
        if (-not (Get-ImageGalleryFlag $entry)) {
            continue
        }

        $published = [System.IO.Path]::GetFileName($key)
        Add-ManifestImage -Images $images -MediaDir $mediaDir -PublishedName $published -Include:$false -Thumbnail:$false -Gallery:$true -Caption:(Get-ImageCaption $entry)
    }

    if ($images.Count -eq 0) {
        Write-Warn "No images inferred for $mediaSlug."
        $skipped++
        continue
    }

    foreach ($image in $images.Values) {
        $sourcePath = Join-Path -Path $mediaDir.FullName -ChildPath $image.Source
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            Write-Warn "${mediaSlug}: inferred source is missing: $($image.Source)"
        }
        elseif ([System.IO.Path]::GetExtension($image.Source) -ieq ".avif") {
            Write-Warn "${mediaSlug}: source falls back to published AVIF; set source manually if a master image exists: $($image.Published)"
        }
    }

    $coverSource = ""
    if (-not [string]::IsNullOrWhiteSpace($coverPublished)) {
        $coverResolved = Resolve-FileName -MediaDir $mediaDir -Name $coverPublished
        $coverImage = $images[$coverResolved.ToLowerInvariant()]
        if ($coverImage) {
            $coverSource = $coverImage.Source
        }
    }

    if ([string]::IsNullOrWhiteSpace($coverSource)) {
        $coverSource = $images.Values[0].Source
    }

    $manifestContent = New-MediaManifestContent -CoverSource $coverSource -Images $images
    $processed++

    if ($Apply) {
        Set-Content -LiteralPath $manifestPath -Value $manifestContent -Encoding UTF8
        Write-Info "Wrote $manifestPath"
        $written++
    }
    else {
        Write-Info "Dry run for $mediaSlug ($($images.Count) image(s)); would write $manifestPath"
        Write-Host $manifestContent
    }
}

if ($Apply) {
    Write-Info "Complete. Processed $processed post(s), wrote $written manifest(s), skipped $skipped."
}
else {
    Write-Info "Dry run complete. Processed $processed post(s), skipped $skipped. Pass -Apply to write _data/media files."
}
