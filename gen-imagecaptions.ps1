<#
.SYNOPSIS
Generates thumbnails for images in a specified folder.

.DESCRIPTION
This function generates thumbnails for images in the specified folder. By default, it does not delete existing thumbnails, but you can enable the deletion of existing thumbnails by setting the $deleteExisting parameter to $true.

.PARAMETER folderPath
The path of the folder containing the images.

.PARAMETER deleteExisting
Specifies whether to delete existing thumbnails before generating new ones. Default value is $false.

.EXAMPLE
GenerateThumbnails -folderPath "C:\Images" -deleteExisting $true
Generates thumbnails for images in the "C:\Images" folder and deletes any existing thumbnails.

#>

param(
   [string]$folderPath = ".\assets\img\posts"
)

function Convert-DateTaken($rawDate) {
   $cleanDate = $rawDate -replace "[^a-zA-Z0-9 -:]", ""
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

function Get-ShellImageMetadata($shell, $imageFile, $titleIndex, $subjectIndex, $dateTakenIndex, $dimensionsIndex, $tagIndex) {
   $shellFolder = $shell.Namespace($imageFile.DirectoryName)
   if (-not $shellFolder) {
      return $null
   }

   $shellFile = $shellFolder.ParseName($imageFile.Name)
   if (-not $shellFile) {
      return $null
   }

   $dimensions = $shellFolder.GetDetailsOf($shellFile, $dimensionsIndex)
   $dimArray = $dimensions -split 'x'
   $width = 0
   $height = 0
   if ($dimArray.Length -ge 2) {
      $width = [int]($dimArray[0] -replace "[^0-9]", "")
      $height = [int]($dimArray[1] -replace "[^0-9]", "")
   }

   $tag = $shellFolder.GetDetailsOf($shellFile, $tagIndex)
   $tagsArray = if ($tag) { $tag -split "\s*;\s*" } else { @() }

   return [pscustomobject]@{
      Title     = $shellFolder.GetDetailsOf($shellFile, $titleIndex)
      Subject   = $shellFolder.GetDetailsOf($shellFile, $subjectIndex)
      DateTaken = Convert-DateTaken $shellFolder.GetDetailsOf($shellFile, $dateTakenIndex)
      Width     = $width
      Height    = $height
      Gallery   = $tagsArray -contains "gallery"
   }
}

function Get-MagickImageDimensions($imageFile) {
   if (-not $script:MagickExecutable) {
      return $null
   }

   $dimensions = & $script:MagickExecutable identify -format "%w %h" $imageFile.FullName 2>$null
   if ($LASTEXITCODE -eq 0 -and $dimensions -match '^(\d+)\s+(\d+)$') {
      return [pscustomobject]@{
         Width  = [int]$matches[1]
         Height = [int]$matches[2]
      }
   }

   return $null
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

function GenerateImageCaptions($folderPath) {
   $repoRoot = (Get-Location).Path

   # Create a Shell.Application object
   $shell = New-Object -ComObject Shell.Application

   # Create a hashtable to store the metadata
   $metadata = @{}

   # Define the property indices for the title, subject, and date taken
   # These indices might vary depending on the version of Windows
   $titleIndex = 21
   $subjectIndex = 22
   $dateTakenIndex = 12
   $dimensionsIndex = 31
   $tagIndex = 18

   try {
      $script:MagickExecutable = (Get-Command "magick" -ErrorAction Stop).Source
   }
   catch {
      $script:MagickExecutable = $null
      Write-Warning "ImageMagick 'magick' executable not found on PATH. Falling back to Windows Shell dimensions."
   }

   #$imageFiles = Get-ChildItem -Path $folderPath -File -Recurse -Depth 2 | Where-Object { $_.Extension -in @('.jpeg', '.jpg', '.png', '.avif') }
   $imageFiles = Get-ChildItem -Path $folderPath -File -Recurse -Depth 2 | Where-Object { $_.Extension -in @('.png', '.avif') }
   # Group files by directory for efficient shell operations
   $filesByFolder = $imageFiles | Group-Object { $_.DirectoryName }

   foreach ($folderGroup in $filesByFolder) {
      Write-Output "Processing folder: $(Split-Path $folderGroup.Name -Leaf)"
      
      foreach ($imageFile in $folderGroup.Group) {
         $metadataKey = [System.IO.Path]::GetRelativePath($repoRoot, $imageFile.FullName).Replace('\', '/')
         $imageMetadata = Get-ShellImageMetadata $shell $imageFile $titleIndex $subjectIndex $dateTakenIndex $dimensionsIndex $tagIndex
         $sourceMetadata = $null
         $sourceFile = Find-MetadataSourceFile $imageFile
         if ($sourceFile -and $sourceFile.FullName -ne $imageFile.FullName) {
            $sourceMetadata = Get-ShellImageMetadata $shell $sourceFile $titleIndex $subjectIndex $dateTakenIndex $dimensionsIndex $tagIndex
         }

         $title = $imageMetadata.Title
         if ([string]::IsNullOrWhiteSpace($title) -and $sourceMetadata) {
            $title = $sourceMetadata.Title
         }

         $subject = $imageMetadata.Subject
         if ([string]::IsNullOrWhiteSpace($subject) -and $sourceMetadata) {
            $subject = $sourceMetadata.Subject
         }

         $dateTaken = $imageMetadata.DateTaken
         if (-not $dateTaken -and $sourceMetadata) {
            $dateTaken = $sourceMetadata.DateTaken
         }

         $width = $imageMetadata.Width
         $height = $imageMetadata.Height
         if ($width -le 0 -or $height -le 0) {
            $magickDimensions = Get-MagickImageDimensions $imageFile
            if ($magickDimensions) {
               $width = $magickDimensions.Width
               $height = $magickDimensions.Height
            }
         }

         $gallery = $imageMetadata.Gallery
         if (-not $gallery -and $sourceMetadata) {
            $gallery = $sourceMetadata.Gallery
         }

         # Store metadata by full site-relative path to disambiguate derivatives.
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

   # Sort the $metadata by filename (key) - maintain existing sorting behavior
   $sortedMetadata = [ordered]@{}
   foreach ($key in ($metadata.Keys | Sort-Object)) {
      $sortedMetadata[$key] = $metadata[$key]
   }

   # Convert the $metadata object to JSON format
   $jsonContent = $sortedMetadata | ConvertTo-Json
   
   # Define the file path for the JSON file
   $jsonFilePath = Join-Path -Path "_data" -ChildPath "img-info.json"

   # Write the JSON content to the file
   $jsonContent | Out-File -FilePath $jsonFilePath -Encoding UTF8
}

# Call the function with the specified folder path
GenerateImageCaptions $folderPath
