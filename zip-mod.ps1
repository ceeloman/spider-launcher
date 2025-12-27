$info = Get-Content 'info.json' | ConvertFrom-Json
$modFolder = '{0}_{1}' -f $info.name, $info.version
$zipname = "$modFolder.zip"
$tempPath = "..\$modFolder"
$zipPath = "..\$zipname"

# Create temp folder with mod name
New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

# Copy files (excluding hidden files and ps1)
Get-ChildItem -Path . -Exclude .*,*.ps1 | Copy-Item -Destination $tempPath -Recurse -Force

# Use tar to create zip with forward slashes
tar -a -c -f $zipPath -C ".." $modFolder

# Clean up temp folder
Remove-Item -Path $tempPath -Recurse -Force

Write-Host "Created $zipname in parent directory"