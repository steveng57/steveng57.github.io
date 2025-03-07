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
   [string]$folderPath = ".\assets\img\posts",
   [bool]$deleteExisting = $false
)

function GenerateThumbnails($folderPath, [bool]$deleteExisting = $false) {
   $tagIndex = 18
   $shell = New-Object -ComObject Shell.Application
   # Get all the subfolders
   $subfolders = Get-ChildItem -Path $folderPath -Directory

   # Loop through each subfolder
   foreach ($subfolder in $subfolders) {
      # Print the name of the subfolder
      Write-Output $subfolder.Name

      # Create a directory called Thumbnails in the subfolder
      $thumbnailsPath = "$($subfolder.FullName)\thumbnails"
      $null = New-Item -Path $thumbnailsPath -ItemType Directory -Force

      # Create a directory called Thumbnails in the subfolder
      $tinyfilesPath = "$($subfolder.FullName)\tinyfiles"
      $null = New-Item -Path $tinyfilesPath -ItemType Directory -Force

      # If the user chose to delete existing thumbnails, delete them
      if ($deleteExisting) {
         $null = Get-ChildItem -Path $thumbnailsPath -File | Remove-Item -Force
         $null = Get-ChildItem -Path $tinyfilesPath -File | Remove-Item -Force
      }

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
         $tag = $shellFolder.GetDetailsOf($shellFile, $tagIndex)
         $tagsArray = $tag -split "\s*;\s*" # Split the tags into an array
         $bGallery = $tagsArray -contains "gallery" # Check if "gallery" is in the tags array
         $bThumbNail = $tagsArray -contains "thumbnail" # Check if "thumbnail" is in the tags array

         if ($bThumbNail) {
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
         
         if ($bGallery) {
            # Check if a tinyfile already exists
            $tinyfilePath = Join-Path -Path $tinyfilesPath -ChildPath $imageFile.Name
            if (-not (Test-Path -Path $tinyfilePath)) {
               Write-Output "Source:" $imageFile.FullName
               Write-Output "Destination:" $tinyfilePath
               # Generate a new thumbnail using Magick
               Write-Output "Convert command: " "convert $($imageFile.FullName) -resize 10% $tinyfilePath"
               Start-Process -FilePath "magick" -ArgumentList "convert `"$($imageFile.FullName)`" -resize 10% `"$tinyfilePath`"" -NoNewWindow -Wait -WorkingDirectory $subfolder.FullName
            }   
         }
      }

      # generate poster file for mp4 files.

      $mp4Files = Get-ChildItem -Path $subfolder.FullName -Filter "*.mp4" -File
      foreach ($mp4File in $mp4Files) {
         $thumbnailPath = Join-Path -Path $thumbnailsPath -ChildPath ($mp4File.BaseName + ".jpeg")
         if (-not (Test-Path -Path $thumbnailPath)) {
            Write-Output "Source:" $mp4File.FullName
            Write-Output "Destination:" $thumbnailPath
            # Generate a new thumbnail using FFMPEG.
            Write-Output "FFMPEG command: " "ffmpeg -i `"$($mp4File.FullName)`" - update 1 -frames:v 1 -q:v 10 `"$thumbnailPath`" -loglevel quiet"
            Start-Process -FilePath "ffmpeg" -ArgumentList "-i `"$($mp4File.FullName)`" -update 1 -frames:v 1 -q:v 10 `"$thumbnailPath`" -loglevel quiet" -NoNewWindow -Wait -WorkingDirectory $subfolder.FullName
         }
      }
   }

}

# Call the function with the specified folder path$folderPath = ".\assets\img\posts"
GenerateThumbnails $folderPath $deleteExisting

