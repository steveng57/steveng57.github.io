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

function GenerateImageCaptions($folderPath) {
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

   $imageFiles = Get-ChildItem -Path $folderPath -File -Recurse -Depth 1 | Where-Object { $_.Extension -in @('.jpeg', '.jpg', '.png', '.avif') }

   # Group files by directory for efficient shell operations
   $filesByFolder = $imageFiles | Group-Object { $_.DirectoryName }

   foreach ($folderGroup in $filesByFolder) {
      Write-Output "Processing folder: $(Split-Path $folderGroup.Name -Leaf)"
      
      # Create shell folder once per directory
      $shellFolder = $shell.Namespace($folderGroup.Name)
      
      foreach ($imageFile in $folderGroup.Group) {
         $file = $imageFile.Name
         $shellFile = $shellFolder.ParseName($file)

         # Get properties
         $title = $shellFolder.GetDetailsOf($shellFile, $titleIndex)
         $subject = $shellFolder.GetDetailsOf($shellFile, $subjectIndex)
         $dateTaken = $shellFolder.GetDetailsOf($shellFile, $dateTakenIndex)
         
         # Parse date taken
         $dateTaken = $dateTaken -replace "[^a-zA-Z0-9 -:]", ""
         $dateTaken = [datetime]$dateTaken
         
         # Parse dimensions more efficiently
         $dimensions = $shellFolder.GetDetailsOf($shellFile, $dimensionsIndex)
         $dimArray = $dimensions -split 'x'
         $width = [int]($dimArray[0] -replace "[^0-9]", "")
         $height = [int]($dimArray[1] -replace "[^0-9]", "")

         $tag = $shellFolder.GetDetailsOf($shellFile, $tagIndex)
         $tagsArray = if ($tag) { $tag -split "\s*;\s*" } else { @() }

         # Store metadata with ordered fields (alphabetically sorted)
         $metadata[$file] = [ordered]@{
            'title'     = $title
            'subject'   = $subject
            'datetaken' = $dateTaken
            'width'     = $width
            'height'    = $height
            'gallery'   = $tagsArray -contains "gallery"
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