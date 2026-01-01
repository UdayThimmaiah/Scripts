# Cleanup unused Static folders
$StaticRoot = '\\192.168.168.60\d$\VitalAxis\Websites-IIS\TITAN-SPRINT-STATIC\V6.87'

$IISRoot = @('\\192.168.168.60\d$\VitalAxis\Websites-IIS', '\\192.168.168.45\d$\VitalAxis\Websites-IIS', '\\192.168.168.81\d$\VitalAxis\Websites-IIS')

[System.Array] $StaticFolders = Get-ChildItem -Path $StaticRoot | Where Name -match '\d{12}'
[System.Array] $IISFolders = Get-ChildItem -Directory -Path $IISRoot

[System.Array] $Files = @()

$i = 0;
foreach($IISFolder in $IISFolders) {
    $i++; $PercentComplete = 100 * $i / $IISFolders.Count
    Write-Progress -Activity "Getting list of Static and IISSite folders..." -Status "$PercentComplete% Complete" -PercentComplete $PercentComplete

    $Files += (Get-ChildItem -File -Path $IISFolder.FullName | Where Name -eq 'VALogin.aspx')
}

[System.Array] $UsedStaticFolders = @()
[System.Array] $UnusedStaticFolders = @()

$i = 0;
$PercentTotal = $StaticFolders.Count * $Files.Count
foreach($StaticFolder in $StaticFolders) {
    foreach($File in $Files) {
        $i++; $PercentComplete = [Math]::round($(100 * $i / $PercentTotal), 2)
        Write-Progress -Activity "Scan in Progress..." -Status "$PercentComplete% Complete" -PercentComplete $PercentComplete

        $FileContent = Get-Content -Path $File.FullName -Raw
        if($FileContent -match $StaticFolder.Name) {
            $UsedStaticFolders += $StaticFolder.FullName
            break;
        }
    }
    if($StaticFolder.FullName -notin $UsedStaticFolders) {
        $UnusedStaticFolders += $StaticFolder.FullName
    }
}

Write-Host "Total  Static Folders: $($StaticFolders.Count)"
Write-Host "Used   Static Folders: $($UsedStaticFolders.Count)"
Write-Host "Unused Static Folders: $($UnusedStaticFolders.Count)"
Write-Host ""


# #---------------------------------------------------------------------------------------------------------
# #-------------------------------------- Delete Unused Static Folders -------------------------------------
# #---------------------------------------------------------------------------------------------------------

foreach($UnusedStaticFolder in $UnusedStaticFolders) {
    $UnusedStaticFolder
    while(Test-Path -Path $UnusedStaticFolder) {
        try {
            Remove-Item -Path $UnusedStaticFolder -Recurse -Force -ErrorAction Stop
        }
        catch {}
    }
}
