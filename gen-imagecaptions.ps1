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

   # Get all the subfolders
   $subfolders = Get-ChildItem -Path $folderPath -Directory

   # Loop through each subfolder
   foreach ($subfolder in $subfolders) {
      # Print the name of the subfolder
      Write-Output $subfolder.Name

      # Get all the image files in the subfolder
      $imageFiles = Get-ChildItem -Path $subfolder.FullName -Filter "*.jpeg" -File
      $imageFiles += Get-ChildItem -Path $subfolder.FullName -Filter "*.jpg" -File
      
      # Loop through each image file in the subfolder
      foreach ($imageFile in $imageFiles) {
         # Get the folder and file objects
         $folder = Split-Path $imageFile
         $file = Split-Path $imageFile -Leaf
         $shellFolder = $shell.Namespace($folder)
         $shellFile = $shellFolder.ParseName($file)

               # Get the properties
         $title = $shellFolder.GetDetailsOf($shellFile, $titleIndex)
         $subject = $shellFolder.GetDetailsOf($shellFile, $subjectIndex)
         $dateTaken = $shellFolder.GetDetailsOf($shellFile, $dateTakenIndex)

         # Add the properties to the hashtable
         $metadata[$file] = @{
            'title' = $title
            'subject' = $subject
            'datetaken' = $dateTaken
         }
      }
   }

   # Convert the $metadata object to JSON format
   $jsonContent = $metadata | ConvertTo-Json
   #$badChar = [char]0x200E
   #$yamlContent = $yamlContent.Replace($badChar, "")
   # Define the file path for the YAML file
   $jsonFilePath = Join-Path -Path "_data" -ChildPath "img-info.json"

   # Write the JSON content to the file
   $jsonContent | Out-File -FilePath $jsonFilePath -Encoding UTF8
}

# Call the function with the specified folder path
$folderPath = ".\assets\img\posts"
GenerateImageCaptions $folderPath
