# Specify the path to the folder
$folderPath = ".\assets\img\posts"

# Get all the subfolders
$subfolders = Get-ChildItem -Path $folderPath -Directory

# Loop through each subfolder
foreach ($subfolder in $subfolders) {
   # Print the name of the subfolder
   Write-Output $subfolder.Name

   # Create a directory called Thumbnails in the subfolder
   New-Item -Path "$($subfolder.FullName)\Thumbnails" -ItemType Directory -Force

   # Delete any files present in the Thumbnails directory
   Remove-Item -Path "$($subfolder.FullName)\Thumbnails\*" -Force
   
   # Execute the Magick program in the Thumbnails directory with the specified parameters
   Start-Process -FilePath "magick" -ArgumentList "mogrify -resize 50% -path $($subfolder.FullName)\Thumbnails *.jpg" -NoNewWindow -Wait -WorkingDirectory $subfolder.FullName 

}