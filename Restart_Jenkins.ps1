param([System.String] $JenkinsServer)

Write-Host "JenkinsServer = $JenkinsServer"

$PropertyMapping = ConvertFrom-StringData (Get-Content "D:\VitalAxis\Jenkins_Build\ORION\Orion.properties" -Raw)
$Username = $PropertyMapping."va.orion.username"
$Password = $PropertyMapping."va.orion.password"
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Credentials = [PSCredential]::new("$Username", $SecurePassword)

Invoke-Command -ComputerName $JenkinsServer -ScriptBlock { Restart-Service -Name 'Jenkins' -Force } -Credential $Credentials
Invoke-Command -ComputerName $JenkinsServer -ScriptBlock { "Status = $((Get-Service -Name 'Jenkins').Status)" } -Credential $Credentials
