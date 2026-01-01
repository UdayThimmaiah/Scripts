# Add certificate to All IIS Sites
# Note: The new certificates "*.vitalaxis.com" and "*.vitalpath.net" should be added in IIS Manager before running this script
$VASslCert = "*vitalaxis.com*"
$VPSslCert = "*vitalpath.net*"

$VACert = (Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -like $VASslCert } | Select-Object -First 1).Thumbprint
$VPCert = (Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -like $VPSslCert } | Select-Object -First 1).Thumbprint

[System.Array] $Sites = Get-IISSite
$i = 1
foreach($Site in $Sites){
    $Url = ''
    $Url = $($Site.Bindings.bindingInformation[1]) -replace '^[*]:\d+:'
    '-----------------------------------------------------------------'
    "($i of $($Sites.Count))  $Url";$i++
    
    if($Site.Bindings.bindingInformation.GetType() -ne [System.String]){
        $Bindings = $Site.Bindings.bindingInformation
        foreach($Binding in $Bindings){
            if($Binding -match '[*]:(443)(.*)'){
                $Guid = [guid]::NewGuid().ToString("B")
                netsh http delete sslcert hostnameport="$($Binding -replace '^[*]:\d+:'):443"
                if($Binding -match 'vitalpath'){
                    netsh http add sslcert hostnameport="$($Binding -replace '^[*]:\d+:'):443" certhash=$VPCert certstorename=MY appid="$Guid"
                }
                else{
                    netsh http add sslcert hostnameport="$($Binding -replace '^[*]:\d+:'):443" certhash=$VACert certstorename=MY appid="$Guid"
                }
            }
        }
    }
}
