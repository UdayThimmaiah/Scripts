# Add certificate to All IIS Sites
# Note: The certificate *.vitalaxis.com should be added in IIS Manager before running this script
[System.Array] $Sites = Get-IISSite
$SslCert = "*vitalaxis.com*"
$SslCertVP = "*vitalpath.net*"
foreach($Site in $Sites){
    $Cert = (Get-ChildItem cert:\LocalMachine\My | where-object { $_.Subject -like $SslCert } | Select-Object -First 1).Thumbprint
    $CertVP = (Get-ChildItem cert:\LocalMachine\My | where-object { $_.Subject -like $SslCertVP} | Select-Object -First 1).Thumbprint

    $Url = $($Site.Bindings.bindingInformation[1]) -replace '^[*]:\d+:'
    
    if($Site.Bindings.bindingInformation.GetType() -ne [System.String]){
        $Bindings = $Site.Bindings.bindingInformation
        foreach($Binding in $Bindings){
            if($Binding -match '[*]:(443)(.*)'){
                $Guid = [guid]::NewGuid().ToString("B")
                
                # Remove existing Certificate
                netsh http delete sslcert hostnameport="$($Binding -replace '^[*]:\d+:'):443"
                
                if($Binding -match 'vitalaxis.com'){
                    netsh http add sslcert hostnameport="$($Binding -replace '^[*]:\d+:'):443" certhash=$Cert certstorename=MY appid="$Guid"
                }
                elseif($Binding -match 'vitalpath.net'){
                    netsh http add sslcert hostnameport="$($Binding -replace '^[*]:\d+:'):443" certhash=$CertVP certstorename=MY appid="$Guid"
                }
            }
        }
    }
}
