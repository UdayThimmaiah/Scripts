# Copy Build and Log folders from new attached drive to D (Destination) drive
[System.Array] $SourceFolders = @(
'G:\VitalAxis\Websites-IIS', 
'G:\VitalAxis\Websites-Logs'
)

[System.String] $DestinationFolder = 'D:\VitalAxis\'

foreach($SourceFolder in $SourceFolders){
    Write-Host "Copying $SourceFolder ..."
    Copy-Item -Path $SourceFolder -Destination $DestinationFolder -Recurse -Force
}