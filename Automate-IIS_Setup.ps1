Param([String] $TeamName = '', [String] $Environment = '', [String] $Deployment = '', [String] $URL = '', [String] $IISServer = '', [String] $LogsServer = '', [String] $FilesServer = '')

$SiteName = "$TeamName-$Environment-$Deployment"

Write-Host "----------------------------------"
Write-Host "Site Name   = $SiteName"
Write-Host "URL         = $URL"
Write-Host ""
Write-Host "IISServer   = $IISServer"
Write-Host "LogsServer  = $LogsServer"
Write-Host "FilesServer = $FilesServer"
Write-Host "----------------------------------"

try{
    $PropertyMapping = ConvertFrom-StringData (Get-Content "D:\VitalAxis\Jenkins_Build\ORION\Orion.properties" -Raw)
    $Username = $PropertyMapping."va.orion.username"
    $Password = $PropertyMapping."va.orion.password"
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credentials = [PSCredential]::new("$Username", $SecurePassword)
}
catch{
    Write-Host "Failed to read credentials from Properties file!"
    throw $_
}

try{
    $WebsitesIIS = "D:\VitalAxis\Websites-IIS\$SiteName"
    $WebsitesLogs = "D:\VitalAxis\Website-Logs\$SiteName\Logs"
    $WebsitesFiles = "D:\VitalAxis\Website-Files\VitalAxis-IIS\$SiteName"

    Invoke-Command -ComputerName $IISServer -ScriptBlock { 
        if(-not(Test-Path $using:WebsitesIIS)){ 
            New-Item -Path $using:WebsitesIIS -ItemType Directory -Force 
        } 
    } -Credential $Credentials
    if($LogsServer -notin @('', '-')){
        Invoke-Command -ComputerName $LogsServer -ScriptBlock { 
            if(-not(Test-Path $using:WebsitesLogs)){ 
                New-Item -Path $using:WebsitesLogs -ItemType Directory -Force 
            } 
        } -Credential $Credentials
    }
    if($FilesServer -notin @('', '-')){
        Invoke-Command -ComputerName $FilesServer -ScriptBlock { 
            if(-not(Test-Path $using:WebsitesFiles)){ 
                New-Item -Path $using:WebsitesFiles -ItemType Directory -Force 
            } 
        } -Credential $Credentials
    }
}
catch{
    Write-Host "Failed to create IIS/Log folders!"
    throw $_
}

try{
    Invoke-Command -ComputerName $IISServer -ScriptBlock { 
        Import-Module WebAdministration;

        New-IISSite -Name $using:SiteName -BindingInformation "*:80:$using:URL" -PhysicalPath $using:WebsitesIIS -Force
        Set-WebConfiguration -Filter "/system.applicationHost/sites/site[@name='$using:SiteName']/application[@path='/']/virtualDirectory[@path='/']" -Value @{userName="ad\$using:Username"; password="$using:Password"}
        New-WebBinding -Name $using:SiteName -IPAddress "*" -Port 443 -Protocol "https" -HostHeader "$using:URL" -SslFlags 1
        
        $SslCert = "*vitalaxis.com*"
        $Cert = (Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -like $SslCert } | Select-Object -First 1).Thumbprint
        (Get-WebBinding -Name $using:SiteName -Port 443 -Protocol "https").AddSslCertificate("$Cert", "My")

        New-WebAppPool -Name $using:SiteName
        Set-ItemProperty "IIS:\Sites\$using:SiteName" applicationPool $using:SiteName;
        Set-ItemProperty IIS:\AppPools\$using:SiteName -Name "processModel" -Value @{ identityType="SpecificUser"; userName="ad\$using:Username"; password="$using:Password" }
    } -Credential $Credentials
}
catch{
    Write-Host "Failed to create IIS Site/AppPool!"
    throw $_
}
