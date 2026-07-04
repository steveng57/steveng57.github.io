<#
.SYNOPSIS
Generates image metadata for post images.

.DESCRIPTION
Scans post image folders and writes `_data/img-info.json`. Keys are full
site-relative paths starting with `assets/` so original images and derived
thumbnail images remain distinct.
#>

param(
   [string]$folderPath = ".\assets\img\posts"
)

function Convert-DateTaken($rawDate) {
   if ($null -eq $rawDate) {
      return $null
   }

   $cleanDate = $rawDate.ToString() -replace "[^a-zA-Z0-9 .:-]", ""
   if ($cleanDate -match '^(\d{4}):(\d{2}):(\d{2})(.*)$') {
      $cleanDate = "$($matches[1])-$($matches[2])-$($matches[3])$($matches[4])"
   }

   if (-not [string]::IsNullOrWhiteSpace($cleanDate)) {
      try {
         return [datetime]$cleanDate
      }
      catch {
         return $null
      }
   }

   return $null
}

function Get-MetadataKey($repoRoot, $imageFile) {
   return [System.IO.Path]::GetRelativePath($repoRoot, $imageFile.FullName).Replace('\', '/')
}

function Convert-ExifArray($value) {
   if ($null -eq $value) {
      return @()
   }

   if ($value -is [array]) {
      return @($value)
   }

   return @($value)
}

function Get-FirstExifValue($metadata, [string[]]$names) {
   if ($null -eq $metadata) {
      return ""
   }

   foreach ($name in $names) {
      if ($metadata.PSObject.Properties.Name -contains $name) {
         $value = $metadata.$name
         if ($value -is [array]) {
            $value = ($value | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
         }
         if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.ToString()
         }
      }
   }

   return ""
}

function Get-ExifTagTokens($metadata) {
   $tokens = @()
   foreach ($name in @('Subject', 'Keywords', 'HierarchicalSubject')) {
      if ($metadata -and $metadata.PSObject.Properties.Name -contains $name) {
         $tokens += Convert-ExifArray $metadata.$name
      }
   }

   return $tokens |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { $_.ToString().Trim().ToLowerInvariant() }
}

function ConvertTo-BoolValue($value) {
   if ($null -eq $value) {
      return $false
   }

   return @('true', 'yes', '1', 'on') -contains $value.ToString().Trim().ToLowerInvariant()
}

function ConvertTo-SiteImageName([string]$imageName) {
   $trimmed = $imageName.Trim().Trim('"').Trim("'")
   $extension = [System.IO.Path]::GetExtension($trimmed).ToLowerInvariant()
   if ($extension -in @('.heic', '.jpg', '.jpeg', '.png')) {
      return ([System.IO.Path]::GetFileNameWithoutExtension($trimmed) + '.avif')
   }

   return $trimmed
}

function Get-PublishedImageName($image) {
   if ($image.PSObject.Properties.Name -contains 'Published' -and -not [string]::IsNullOrWhiteSpace($image.Published)) {
      return $image.Published
   }

   return ConvertTo-SiteImageName $image.Source
}

function Read-MediaManifest($folder) {
   $manifestPath = Join-Path -Path $folder.FullName -ChildPath "media.yml"
   if (-not (Test-Path -LiteralPath $manifestPath)) {
      return $null
   }

   $manifest = [ordered]@{
      Cover  = ""
      Images = @()
   }
   $current = $null
   $section = ""

   foreach ($line in Get-Content -LiteralPath $manifestPath) {
      if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) {
         continue
      }

      if ($line -match '^\s*cover:\s*(.+?)\s*$') {
         $manifest.Cover = $matches[1].Trim().Trim('"').Trim("'")
         continue
      }

      if ($line -match '^\s*images:\s*$') {
         $section = "images"
         continue
      }

      if ($line -match '^\s*videos:\s*$') {
         $section = "videos"
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
         continue
      }

      if ($section -eq "images" -and $current -and $line -match '^\s*(published|include|gallery|thumbnail|caption):\s*(.*?)\s*$') {
         $key = $matches[1].ToLowerInvariant()
         $value = $matches[2].Trim().Trim('"').Trim("'")
         switch ($key) {
            'published' { $current.Published = $value }
            'include' { $current.Include = ConvertTo-BoolValue $value }
            'gallery' { $current.Gallery = ConvertTo-BoolValue $value }
            'thumbnail' { $current.Thumbnail = ConvertTo-BoolValue $value }
            'caption' { $current.Caption = $value }
         }
      }
   }

   if ($current) {
      $manifest.Images += [pscustomobject]$current
   }

   return [pscustomobject]$manifest
}

function Get-MediaIntentMap($folderPath) {
   $intentMap = @{}
   $manifestFiles = @(Get-ChildItem -Path $folderPath -Filter "media.yml" -File -Recurse -ErrorAction SilentlyContinue)
   $postFolders = @($manifestFiles | ForEach-Object { $_.Directory })

   foreach ($postFolder in $postFolders) {
      $manifest = Read-MediaManifest $postFolder
      if (-not $manifest) {
         continue
      }

      foreach ($image in $manifest.Images) {
         $published = Get-PublishedImageName $image
         foreach ($relativeName in @($published, "thumbnails/$published", "thumbnails-2x/$published", "tinyfiles/$published")) {
            $key = (Join-Path -Path $postFolder.FullName -ChildPath ($relativeName -replace '/', [System.IO.Path]::DirectorySeparatorChar))
            $intentMap[$key] = $image
         }
      }
   }

   return $intentMap
}

function Find-MetadataSourceFile($imageFile) {
   $metadataDirectory = $imageFile.Directory
   if (@('thumbnails', 'thumbnails-2x', 'tinyfiles') -contains $metadataDirectory.Name) {
      $metadataDirectory = $metadataDirectory.Parent
   }

   foreach ($extension in @('.png', '.jpg', '.jpeg', '.heic')) {
      $candidatePath = Join-Path -Path $metadataDirectory.FullName -ChildPath ($imageFile.BaseName + $extension)
      if (Test-Path -LiteralPath $candidatePath) {
         return Get-Item -LiteralPath $candidatePath
      }
   }

   return $null
}

function Get-ExifMetadataMap($repoRoot, $imageFiles) {
   try {
      $exifTool = (Get-Command "exiftool" -ErrorAction Stop).Source
   }
   catch {
      throw "ExifTool executable not found on PATH."
   }

   $argFile = [System.IO.Path]::GetTempFileName()

   try {
      $arguments = @(
         "-json",
         "-Title",
         "-ImageDescription",
         "-Description",
         "-XPTitle",
         "-XPSubject",
         "-Subject",
         "-Keywords",
         "-HierarchicalSubject",
         "-DateTimeOriginal",
         "-CreateDate",
         "-ImageWidth",
         "-ImageHeight"
      )

      $arguments += $imageFiles | ForEach-Object { $_.FullName }
      Set-Content -LiteralPath $argFile -Value $arguments -Encoding UTF8

      $previousLcAll = $env:LC_ALL
      $previousLang = $env:LANG
      $env:LC_ALL = "C"
      $env:LANG = "C"
      $json = & $exifTool "-@" $argFile
      if ($LASTEXITCODE -ne 0) {
         throw "ExifTool exited with code $LASTEXITCODE."
      }
   }
   finally {
      $env:LC_ALL = $previousLcAll
      $env:LANG = $previousLang
      Remove-Item -LiteralPath $argFile -Force -ErrorAction SilentlyContinue
   }

   $metadataMap = @{}
   $metadataItems = $json | ConvertFrom-Json
   foreach ($item in $metadataItems) {
      $sourcePath = $item.SourceFile
      if (-not [System.IO.Path]::IsPathRooted($sourcePath)) {
         $sourcePath = Join-Path -Path $repoRoot -ChildPath $sourcePath
      }

      $key = [System.IO.Path]::GetRelativePath($repoRoot, $sourcePath).Replace('\', '/')
      $metadataMap[$key] = $item
   }

   return $metadataMap
}

function GenerateImageCaptions($folderPath) {
   $repoRoot = (Get-Location).Path
   $metadata = @{}
   $mediaIntentMap = Get-MediaIntentMap $folderPath

   $imageFiles = Get-ChildItem -Path $folderPath -File -Recurse -Depth 3 |
      Where-Object { $_.Extension.ToLowerInvariant() -in @('.png', '.avif') }

   $sourceFiles = $imageFiles | ForEach-Object { Find-MetadataSourceFile $_ } | Where-Object { $_ }
   $metadataFilesByPath = @{}
   foreach ($file in ($imageFiles + $sourceFiles)) {
      $metadataFilesByPath[$file.FullName] = $file
   }

   $exifMetadata = Get-ExifMetadataMap $repoRoot $metadataFilesByPath.Values
   $filesByFolder = $imageFiles | Group-Object { $_.DirectoryName }

   foreach ($folderGroup in $filesByFolder) {
      Write-Output "Processing folder: $(Split-Path $folderGroup.Name -Leaf)"

      foreach ($imageFile in $folderGroup.Group) {
         $metadataKey = Get-MetadataKey $repoRoot $imageFile
         $imageMetadata = $exifMetadata[$metadataKey]

         $sourceMetadata = $null
         $sourceFile = Find-MetadataSourceFile $imageFile
         if ($sourceFile -and $sourceFile.FullName -ne $imageFile.FullName) {
            $sourceMetadata = $exifMetadata[(Get-MetadataKey $repoRoot $sourceFile)]
         }

         $title = Get-FirstExifValue $imageMetadata @('Title', 'ImageDescription', 'Description', 'XPTitle')
         if ([string]::IsNullOrWhiteSpace($title) -and $sourceMetadata) {
            $title = Get-FirstExifValue $sourceMetadata @('Title', 'ImageDescription', 'Description', 'XPTitle')
         }

         $subject = Get-FirstExifValue $imageMetadata @('XPSubject', 'ImageDescription', 'Description', 'Title', 'XPTitle')
         if ([string]::IsNullOrWhiteSpace($subject) -and $sourceMetadata) {
            $subject = Get-FirstExifValue $sourceMetadata @('XPSubject', 'ImageDescription', 'Description', 'Title', 'XPTitle')
         }

         $intent = $mediaIntentMap[$imageFile.FullName]
         if ($intent -and -not [string]::IsNullOrWhiteSpace($intent.Caption)) {
            $title = $intent.Caption
            $subject = $intent.Caption
         }

         $dateTaken = Convert-DateTaken (Get-FirstExifValue $imageMetadata @('DateTimeOriginal', 'CreateDate'))
         if (-not $dateTaken -and $sourceMetadata) {
            $dateTaken = Convert-DateTaken (Get-FirstExifValue $sourceMetadata @('DateTimeOriginal', 'CreateDate'))
         }

         $width = if ($imageMetadata.ImageWidth) { [int]$imageMetadata.ImageWidth } else { 0 }
         $height = if ($imageMetadata.ImageHeight) { [int]$imageMetadata.ImageHeight } else { 0 }

         $tagTokens = @(Get-ExifTagTokens $imageMetadata)
         if ($tagTokens.Count -eq 0 -and $sourceMetadata) {
            $tagTokens = @(Get-ExifTagTokens $sourceMetadata)
         }
         $gallery = $tagTokens -contains "gallery"
         if ($intent) {
            $gallery = [bool]$intent.Gallery
         }

         $metadata[$metadataKey] = [ordered]@{
            'title'     = $title
            'subject'   = $subject
            'datetaken' = $dateTaken
            'width'     = $width
            'height'    = $height
            'gallery'   = $gallery
         }
      }
   }

   $sortedMetadata = [ordered]@{}
   foreach ($key in ($metadata.Keys | Sort-Object)) {
      $sortedMetadata[$key] = $metadata[$key]
   }

   $jsonContent = $sortedMetadata | ConvertTo-Json
   $jsonFilePath = Join-Path -Path "_data" -ChildPath "img-info.json"
   $jsonContent | Out-File -FilePath $jsonFilePath -Encoding UTF8
}

GenerateImageCaptions $folderPath
