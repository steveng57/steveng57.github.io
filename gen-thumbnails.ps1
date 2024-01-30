# Specify the path to the folder
$folderPath = ".\assets\img\posts"

# Get all the subfolders
$subfolders = Get-ChildItem -Path $folderPath -Directory

# Ask the user if existing thumbnails should be deleted
$deleteExisting = Read-Host -Prompt "Should existing thumbnails be deleted? (yes/no)"

# Loop through each subfo  lder
foreach ($subfolder in $subfolders) {
   # Print the name of the subfolder
   Write-Output $subfolder.Name

   # Create a directory called Thumbnails in the subfolder
   $thumbnailsPath = "$($subfolder.FullName)\Thumbnails"
   New-Item -Path $thumbnailsPath -ItemType Directory -Force

  # If the user chose to delete existing thumbnails, delete them
  if ($deleteExisting -eq "yes") {
    Get-ChildItem -Path $thumbnailsPath -File | Remove-Item -Force
  }


   # Loop through each image file in the subfolder
   $imageFiles = Get-ChildItem -Path $subfolder.FullName -Filter "*.jpeg" -File
   $imageFiles += Get-ChildItem -Path $subfolder.FullName -Filter "*.jpg" -File
   
   foreach ($imageFile in $imageFiles) {
      Write-Output "Source:" $imageFile.FullName
      # Check if a thumbnail already exists
      $thumbnailPath = Join-Path -Path $thumbnailsPath -ChildPath $imageFile.Name
      Write-Output "Destination:" $thumbnailPath
      if (-not (Test-Path -Path $thumbnailPath)) {
         # Generate a new thumbnail using Magick
         Write-Output "Convert command: " "convert $($imageFile.FullName) -resize 50% $thumbnailPath"
         Start-Process -FilePath "magick" -ArgumentList "convert $($imageFile.FullName) -resize 50% $thumbnailPath" -NoNewWindow -Wait -WorkingDirectory $subfolder.FullName
      }
   }
}

