# List Private IP of Azure VMs

Get-AzVM -Name 'VAWEBSTAGE01'

$NetworkInterfaces = Get-AzResource -ResourceType "Microsoft.Network/networkInterfaces"
$NIC = $NetworkInterfaces | Where Name -match 'webstage'
#foreach ($NIC in $NetworkInterfaces) {
    $NIC = Get-AzResource -ResourceType "Microsoft.Network/networkInterfaces" -ResourceGroupName $NIC.ResourceGroupName -Name $NIC.Name -ExpandProperties -ApiVersion '2024-10-01'
    $IpConfigs = $NIC.Properties.ipConfigurations
    foreach ($IpConfig in $IpConfigs) {
        $PrivateIp = $IpConfig.properties.privateIPAddress
        Write-Output "Private IP: $PrivateIp"
    }
#}
