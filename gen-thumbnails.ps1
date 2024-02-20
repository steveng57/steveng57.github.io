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
function GenerateThumbnails($folderPath, [bool]$deleteExisting = $false) {

   # Get all the subfolders
   $subfolders = Get-ChildItem -Path $folderPath -Directory

   # Loop through each subfolder
   foreach ($subfolder in $subfolders) {
      # Print the name of the subfolder
      Write-Output $subfolder.Name

      # Create a directory called Thumbnails in the subfolder
      $thumbnailsPath = "$($subfolder.FullName)\thumbnails"
      $null = New-Item -Path $thumbnailsPath -ItemType Directory -Force

      # If the user chose to delete existing thumbnails, delete them
      if ($deleteExisting) {
         $null = Get-ChildItem -Path $thumbnailsPath -File | Remove-Item -Force
      }

      # Get all the image files in the subfolder
      $imageFiles = Get-ChildItem -Path $subfolder.FullName -Filter "*.jpeg" -File
      $imageFiles += Get-ChildItem -Path $subfolder.FullName -Filter "*.jpg" -File
      
      # Loop through each image file in the subfolder
      foreach ($imageFile in $imageFiles) {
         # Check if a thumbnail already exists
         $thumbnailPath = Join-Path -Path $thumbnailsPath -ChildPath $imageFile.Name
         if (-not (Test-Path -Path $thumbnailPath)) {
            Write-Output "Source:" $imageFile.FullName
            Write-Output "Destination:" $thumbnailPath
            # Generate a new thumbnail using Magick
            Write-Output "Convert command: " "convert $($imageFile.FullName) -resize 50% $thumbnailPath"
            Start-Process -FilePath "magick" -ArgumentList "convert `"$($imageFile.FullName)`" -resize 50% `"$thumbnailPath`"" -NoNewWindow -Wait -WorkingDirectory $subfolder.FullName
         }
      }
   }
}

# Call the function with the specified folder path
$folderPath = ".\assets\img\posts"
GenerateThumbnails $folderPath $false

