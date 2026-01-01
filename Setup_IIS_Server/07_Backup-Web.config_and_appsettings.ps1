# Copy Web.config and appsettings.json files with folder structure
$SourceFolder = 'D:\VitalAxis\Websites-IIS'
$DestinationFolder = 'D:\Export\Websites-IIS'

$Sites = Get-ChildItem -Path $SourceFolder

foreach($Site in $Sites){
    [System.Array] $ConfigFiles = @()
    $ConfigFiles += Get-ChildItem -Path "$SourceFolder\$($Site.Name)" -Filter 'Web.config'
    $ConfigFiles += Get-ChildItem -Path "$SourceFolder\$($Site.Name)" -Filter 'appsettings.json'

    $DestinationRootFolder = $Site.FullName.Replace($SourceFolder, $DestinationFolder)
    
    # if(($ConfigFiles.Length -gt 0) -and (-not(Test-Path -Path $DestinationRootFolder))){ 
    if((-not(Test-Path -Path $DestinationRootFolder))){ 
        New-Item -ItemType Directory -Path $DestinationRootFolder
    }
    
    foreach($ConfigFile in $ConfigFiles){
        Copy-Item -Path $ConfigFile.FullName -Destination $DestinationRootFolder -Force
    }
}
