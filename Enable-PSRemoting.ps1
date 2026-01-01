# Allow PowerShell Scripts Execution via Remote machine

# Run on machineA
Get-Item WSMan:\localhost\Client\TrustedHosts | SELECT Value
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'machineC' -Concatenate

# Run on machineC
Get-Item WSMan:\localhost\Client\TrustedHosts | SELECT Value
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'machineA' -Concatenate
