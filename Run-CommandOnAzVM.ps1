
$AzVM = Get-AzVM -Name 'VADFSSTAGE01'

Invoke-AzVMRunCommand -ResourceGroupName $AzVM.ResourceGroupName -VMName $AzVM.Name -CommandId "RunPowerShellScript" -ScriptString @"
Get-ChildItem -Path E:\Windows-Services\STAGE
"@
