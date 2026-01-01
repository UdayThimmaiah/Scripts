# #################################################
[System.Array] $ServiceNames = @("VA_JUPITER_QC_THX_GenerateCoversheet",
"VA_JUPITER_QC_THX_GenerateMappingSheet_NYR",
"VA_JUPITER_QC_THX_GenerateWorkSheetForBulkProcessing",
"VA_JUPITER_QC_THX_L2LReportFileCopy",
"VA_JUPITER_QC_THX_L2LSupplimentReportGen",
"VA_JUPITER_QC_THX_PathologistDataSync",
"VA_JUPITER_QC_THX_ProcessCTREnrollments",
"VA_JUPITER_QC_THX_RescreeingRule",
"VA_JUPITER_QC_THX_SendSMSWindowsService",
"VA_JUPITER_QC_THX_SignoutandGeneratetReport",
"VA_JUPITER_QC_THX_SupplementalFileCopy",
"VA_JUPITER_QC_THX_Titan_SendSMSWindowsService",
"VA_JUPITER_QC_THX_VABulkOrderService",
"VA_JUPITER_QC_THX_VitalOrdersDataSync",
"VA_JUPITER_QC_THX_FailedAttachmentFileService",
"VA_JUPITER_QC_THX_VitalSupplyDataSync")

foreach($ServiceName in $ServiceNames){
    Stop-Service -Name "$ServiceName";
    Start-Sleep -Seconds 3;
    Remove-Item -Recurse -Force -Path ((Get-WmiObject win32_service | WHERE Name -eq "$ServiceName").PathName  -replace('\\[^\\]+$') );
    Remove-Item -Recurse -Force -Path ((Get-WmiObject win32_service | WHERE Name -eq "$ServiceName").PathName.Replace("InstallFiles", "InstallLogs")  -replace('\\[^\\]+$') );
    sc.exe delete "$ServiceName"
}
# #################################################