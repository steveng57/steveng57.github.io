# Define the path to the images folder
$imagesPath = "d:/dev/Source/Repos/steveng57.github.io/assets/img/posts"

# Get all JPEG files in the folder and subfolders
$jpegFiles = Get-ChildItem -Path $imagesPath -Recurse -Filter *.jpeg -Depth 1
$titleIndex = 21
$tagIndex = 18
# Create a Shell.Application object
$shell = New-Object -ComObject Shell.Application

foreach ($imageFile in $jpegFiles) {
    # Check if the filename does not begin with 'x'
    if ($imageFile.Name -notmatch '^x') {
        # Get the folder and file objects
        $folder = Split-Path $imageFile
        $file = Split-Path $imageFile -Leaf
        $shellFolder = $shell.Namespace($folder)
        $shellFile = $shellFolder.ParseName($file)
        $title = $shellFolder.GetDetailsOf($shellFile, $titleIndex)
        $title
        # Set the extended file attribute "Tags" to "gallery"
        $currentTags = $shellFolder.GetDetailsOf($shellFile, $tagIndex)
        $currentTags
    }
}