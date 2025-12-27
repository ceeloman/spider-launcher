$info = Get-Content 'info.json' | ConvertFrom-Json
$modFolder = '{0}_{1}' -f $info.name, $info.version
$zipname = "$modFolder.zip"
$tempPath = "..\$modFolder"

# Create temp folder with mod name
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

# Copy files (excluding hidden files and ps1)
Get-ChildItem -Path . -Exclude .*,*.ps1 | Copy-Item -Destination $tempPath -Recurse -Force

# Create zip from the folder
Compress-Archive -Path $tempPath -DestinationPath "..\$zipname" -Force

# Clean up temp folder
Remove-Item -Path $tempPath -Recurse -Force

Write-Host "Created $zipname in parent directory"