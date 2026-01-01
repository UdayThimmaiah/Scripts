# Export and Import all IIS Sites and AppPools
Write-Host '1. Export'
Write-Host '2. Import'
$Choice = Read-Host 'Enter your choice'

if($Choice -eq '1'){
    ### # Export:
    cmd.exe /c 'inetsrv\appcmd list apppool /config /xml > D:\IIS_AppPools.xml'
    cmd.exe /c 'inetsrv\appcmd list site /config /xml > D:\IIS_Sites.xml'
}
elseif($Choice -eq '2'){
    ### # Import:
    cmd.exe /c 'inetsrv\appcmd add apppool /in < D:\IIS_AppPools.xml'
    cmd.exe /c 'inetsrv\appcmd add site /in < D:\IIS_Sites.xml'
}
