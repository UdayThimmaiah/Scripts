param($Server = '')

Write-Host "Server = $Server"
Write-Host ""

$SourceFolder = "\\$Server\d$\VitalAxis\Websites-IIS"
$DestinationFolder = "D:\VitalAxis\ConfigFiles-Backup\Websites-IIS\$Server"

$Date = (Get-Date).ToString('yyyy-MM-dd')

if(-not(Test-Path -Path "$DestinationFolder\$Date")) {
    New-Item -ItemType Directory -Path "$DestinationFolder\$Date" | Out-Null
}

try {
    Get-ChildItem -Path $DestinationFolder | Select -SkipLast 7 | Remove-Item -Recurse -Force
}
catch {}

$DestinationFolder = "$DestinationFolder\$Date"

$Sites = Get-ChildItem -Path $SourceFolder -Directory

foreach($Site in $Sites) {
    [System.Array] $ConfigFiles = @()
    $ConfigFiles += Get-ChildItem -Path "$SourceFolder\$($Site.Name)" -Filter 'Web.config'
    $ConfigFiles += Get-ChildItem -Path "$SourceFolder\$($Site.Name)" -Filter 'appsettings.json'

    $DestinationRootFolder = $Site.FullName.Replace($SourceFolder, $DestinationFolder)
    
    if(($ConfigFiles.Length -gt 0) -and (-not(Test-Path -Path $DestinationRootFolder))) { 
        New-Item -ItemType Directory -Path $DestinationRootFolder | Out-Null
    }
    
    foreach($ConfigFile in $ConfigFiles) {
        Write-Host "Copying $($ConfigFile.FullName.Replace($SourceFolder, ''))"
        Copy-Item -Path $ConfigFile.FullName -Destination $DestinationRootFolder -Force
    }
}

Write-Host ""
