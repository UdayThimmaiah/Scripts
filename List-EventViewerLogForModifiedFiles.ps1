# Scan Event Viewer logs for modifications of given file name within given time range
$StartTime = '2025-06-30 15:43'
$EndTime   = '2025-06-30 15:44'
$FileName  = 'Test-FileAuditLog.txt'

$Events = Get-WinEvent -LogName Security | Where { ($_.TimeCreated.ToString('yyyy-MM-dd HH:mm') -ge $StartTime) -and ($_.TimeCreated.ToString('yyyy-MM-dd HH:mm') -le $EndTime) }
$Events | Where { $_.Message -match [regex]::Escape($FileName) } | Format-List -Property TimeCreated, Message
