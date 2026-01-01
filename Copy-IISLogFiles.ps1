$LogFilesRoot = 'C:\inetpub\logs\LogFiles'
$DestinationFolder = 'D:\LogFiles'

$IISSites = Get-IISSite

$LogFolders = Get-ChildItem -Path $LogFilesRoot

foreach($LogFolder in $LogFolders){
    $FolderName = $LogFolder.Name
    $SiteID = $FolderName -replace '^(W3SVC)(\d+)', '$2'
    $SiteName = $IISSites | WHERE ID -eq $SiteID

    New-Item -ItemType Directory -Path "$DestinationFolder\$SiteName" -Force -ErrorAction Stop | Out-Null
    
    #Get-ChildItem -Path $LogFolder.FullName -File | WHERE LastWriteTime -GT (Get-Date).AddDays(-1) | Copy-Item -Destination "$DestinationFolder\$SiteName" -Force
    Get-ChildItem -Path $LogFolder.FullName -File | Sort -Property LastWriteTime -Descending | Select -First 1 | Copy-Item -Destination "$DestinationFolder\$SiteName" -Force
}
