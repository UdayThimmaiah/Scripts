# Allow Running PowerShell Scripts remotely by adding server to winrm Trusted List
(Get-Item WSMan:\localhost\Client\TrustedHosts)

#### # Run on IISServer :
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'JenkinsServer' -Concatenate

#### # Run on JenkinsServer :
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'IISServer' -Concatenate