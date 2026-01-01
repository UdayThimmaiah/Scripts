# Allow Running PowerShell Scripts remotely by adding server to winrm Trusted List
(Get-Item WSMan:\localhost\Client\TrustedHosts)

#### # Run on ServerA :
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'ServerB' -Concatenate

#### # Run on ServerB :
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'ServerA' -Concatenate