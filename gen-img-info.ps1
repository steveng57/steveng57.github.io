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

function Get-DisplayDimensions($metadata) {
   $width = if ($metadata -and $metadata.ImageWidth) { [int]$metadata.ImageWidth } else { 0 }
   $height = if ($metadata -and $metadata.ImageHeight) { [int]$metadata.ImageHeight } else { 0 }

   if ($width -le 0 -or $height -le 0) {
      return [pscustomobject]@{
         Width  = $width
         Height = $height
      }
   }

   $orientation = ""
   if ($metadata -and $metadata.PSObject.Properties.Name -contains 'Orientation') {
      $orientation = $metadata.Orientation.ToString()
   }

   if ($orientation -match '\b(90|270)\b') {
      return [pscustomobject]@{
         Width  = $height
         Height = $width
      }
   }

   return [pscustomobject]@{
      Width  = $width
      Height = $height
   }
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
         "-DateTimeOriginal",
         "-CreateDate",
         "-Orientation",
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

function GenerateImageMetadata($folderPath) {
   $repoRoot = (Get-Location).Path
   $metadata = @{}

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

         $dateTaken = Convert-DateTaken (Get-FirstExifValue $imageMetadata @('DateTimeOriginal', 'CreateDate'))
         if (-not $dateTaken -and $sourceMetadata) {
            $dateTaken = Convert-DateTaken (Get-FirstExifValue $sourceMetadata @('DateTimeOriginal', 'CreateDate'))
         }

         $displayDimensions = Get-DisplayDimensions $imageMetadata

         $metadata[$metadataKey] = [ordered]@{
            'title'     = $title
            'subject'   = $subject
            'datetaken' = $dateTaken
            'width'     = $displayDimensions.Width
            'height'    = $displayDimensions.Height
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

GenerateImageMetadata $folderPath
