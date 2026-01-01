# Copy Build and Log folders from new attached drive (Backup Source) to D:\ (Destination) drive
[System.Array] $SourceFolders = @(
'F:\VitalAxis\Websites-IIS', 
'F:\VitalAxis\Website-Logs'
)

[System.String] $DestinationFolder = 'D:\VitalAxis\'

foreach($SourceFolder in $SourceFolders){
    Write-Host "Copying $SourceFolder ..."
    Copy-Item -Path $SourceFolder -Destination $DestinationFolder -Recurse -Force
}