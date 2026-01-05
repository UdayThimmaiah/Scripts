param([string] $Server, [string] $Operation, [string] $IISSite)

Write-Host "Server    = $Server"
Write-Host "Operation = $Operation"
Write-Host "IISSite   = $IISSite"
Write-Host ""

$PropertyMapping = ConvertFrom-StringData (Get-Content "D:\VitalAxis\Jenkins_Build\ORION\Orion.properties" -Raw)
$Username = $PropertyMapping."va.orion.username"
$Password = $PropertyMapping."va.orion.password"
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Credentials = [PSCredential]::new("$Username", $SecurePassword)

if($Operation -eq 'Stop'){
    Invoke-Command -ComputerName $Server -ScriptBlock { Stop-IISSite -Name "$using:IISSite" -Confirm:$False } -Credential $Credentials
    Invoke-Command -ComputerName $Server -ScriptBlock { Stop-WebAppPool -Name "$using:IISSite" } -Credential $Credentials
}
elseif($Operation -eq 'Start'){
    Invoke-Command -ComputerName $Server -ScriptBlock { Start-IISSite -Name "$using:IISSite" } -Credential $Credentials
    Invoke-Command -ComputerName $Server -ScriptBlock { Start-WebAppPool -Name "$using:IISSite" } -Credential $Credentials
}
elseif($Operation -eq 'Restart'){
    Invoke-Command -ComputerName $Server -ScriptBlock { Stop-IISSite -Name "$using:IISSite" -Confirm:$False } -Credential $Credentials
    Invoke-Command -ComputerName $Server -ScriptBlock { Write-Host "State =  $((Get-IISSite "$using:IISSite").State)" } -Credential $Credentials
    Invoke-Command -ComputerName $Server -ScriptBlock { Restart-WebAppPool -Name "$using:IISSite" } -Credential $Credentials
    Invoke-Command -ComputerName $Server -ScriptBlock { Start-IISSite -Name "$using:IISSite" } -Credential $Credentials
}

Invoke-Command -ComputerName $Server -ScriptBlock { Write-Host "State =  $((Get-IISSite "$using:IISSite").State)" } -Credential $Credentials
