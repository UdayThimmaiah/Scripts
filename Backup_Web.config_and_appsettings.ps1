$Server = '192.168.168.60'

$SourceFolder = "\\$Server\d$\VitalAxis\Websites-IIS"
$DestinationFolder = "\\$Server\d$\VitalAxis\Config-Backup"

$Sites = Get-ChildItem -Path $SourceFolder

foreach($Site in $Sites){
    [System.Array] $ConfigFiles = @()
    $ConfigFiles += Get-ChildItem -Path "$SourceFolder\$($Site.Name)" -Filter 'Web.config'
    $ConfigFiles += Get-ChildItem -Path "$SourceFolder\$($Site.Name)" -Filter 'appsettings.json'

    $DestinationRootFolder = $Site.FullName.Replace($SourceFolder, $DestinationFolder)
    
    if(($ConfigFiles.Length -gt 0) -and (-not(Test-Path -Path $DestinationRootFolder))){ 
        New-Item -ItemType Directory -Path $DestinationRootFolder
    }
    
    foreach($ConfigFile in $ConfigFiles){
        Copy-Item -Path $ConfigFile.FullName -Destination $DestinationRootFolder -Force
    }
}
