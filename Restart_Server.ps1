param([System.String] $Server)

Write-Host "Server = $Server"

$PropertyMapping = ConvertFrom-StringData (Get-Content "D:\VitalAxis\Jenkins_Build\ORION\Orion.properties" -Raw)
$Username = $PropertyMapping."va.orion.username"
$Password = $PropertyMapping."va.orion.password"
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Credentials = [PSCredential]::new("$Username", $SecurePassword)

Invoke-Command -ComputerName $Server -ScriptBlock { Restart-Computer -Force } -Credential $Credentials
