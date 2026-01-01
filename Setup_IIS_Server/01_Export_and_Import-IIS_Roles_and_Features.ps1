# Export/Import IIS Roles and Installed Features List 
$ExportPath = "D:\IISRoles.txt"
$ImportPath = "D:\IISRoles.txt"


Write-Host "1. Export"
Write-Host "2. Import"
$Choice = Read-Host "Enter your choice"

if($Choice -eq "1"){
    $Roles = Get-WindowsFeature
    $Roles | Where-Object { $_.Installed } | Out-File -FilePath $ExportPath
    $Roles | Where-Object { $_.Installed } | SELECT Name | Out-File -FilePath $ExportPath
}
elseif($Choice -eq "2"){
    $Roles = Get-Content $ImportPath
    foreach ($Role in $Roles) {
        $RoleName = $Role.Trim("- ");
        if(($RoleName.length -gt 0) -and ($RoleName -ne "Name")){
            Write-Output "Enabling $RoleName..."
            Add-WindowsFeature $RoleName
        }
    }
}