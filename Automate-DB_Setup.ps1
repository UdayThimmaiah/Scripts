Param([String] $DBName = '', [String] $DBServer = '', [String] $DBSource = '', [String] $DBSourceDeployment = '')

Write-Host "----------------------------------"
Write-Host "Database Name    = $DBName"
Write-Host "Database Server  = $DBServer"
Write-Host "Database Source  = $DBSource, $DBSourceDeployment"
Write-Host "----------------------------------"

try {
    $PropertyMapping = ConvertFrom-StringData (Get-Content "D:\VitalAxis\Jenkins_Build\ORION\Orion.properties" -Raw)
    $Username = $PropertyMapping."va.orion.username"
    $Password = $PropertyMapping."va.orion.password"
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credentials = [PSCredential]::new("$Username", $SecurePassword)
}
catch {
    Write-Host "Failed to read credentials from Properties file!"
    throw $_
}


if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Install-Module -Name SqlServer
}
Import-Module SqlServer

$Database = $DBName
$ServerInstance = $DBServer

$DataPath   = "D:\VitalAxis\DBFILES\DATA"
$LogPath    = "D:\VitalAxis\DBFILES\LOG"
$MemoryPath = "D:\VitalAxis\DBFILES\FILESTREAM"

if($DBSource -eq '192.168.168.49') {
    $BackupFileRootPath = "\\192.168.168.49\LocalDBBackup\DB_RESTORE_AUTOMATION"

    $BackupFileRootPath = "$BackupFileRootPath\$DBSourceDeployment"
    $BackupFile = (Get-ChildItem "$BackupFileRootPath" | Select FullName, LastWriteTime | Sort-Object -Descending -Property 'LastWriteTime')[0].FullName
}
else {
    Backup-SqlDatabase -ServerInstance "$DBSource" -Database "$DBSourceDeployment" -BackupFile "\\$DBSource\d$\SQL-DB-BACKUP\$DBName.bak" -Credential $Credentials
    $BackupFile = "\\$DBServer\d$\SQL-DB-BACKUP\$DBSourceDeployment.bak"
    if(Test-Path -LiteralPath "$BackupFile") {
        Remove-Item -LiteralPath "$BackupFile" -Force
    }
    Move-Item -LiteralPath "\\$DBSource\d$\SQL-DB-BACKUP\$DBName.bak" -Destination "$BackupFile"
}


# Get Logical File Names
$DataFileLogicalName1 = ""
$DataFileLogicalName2 = ""
$LogFileLogicalName = ""
$MemoryFileLogicalName = ""

# Stop ETL Jobs
Write-Host 'Stopping ETL Job'
if($Database -in @('TITAN-SPRINT-BCM', 'TITAN-SPRINT-LIS', 'TITAN-SPRINT-MYLIS', 'TITAN-SPRINT-PROGRAMS', 'TITAN-SPRINT-SAGIS', 'TITAN-SPRINT-SOLARIS', 'TITAN-SPRINT-TLA', 'TITAN-SPRINT-UPM', 'TITAN-SPRINT-VPLABS')) {
    Invoke-Sqlcmd -ServerInstance '192.168.168.51' -Database 'msdb' -Credential $Credentials -Query "EXECUTE sp_update_job @job_name = '$($Database -replace '\w+-\w+-', 'ETL_')', @enabled = 0;" -ErrorAction SilentlyContinue
}


if(Get-SqlDatabase -ServerInstance "$ServerInstance" -Name "$Database" -Credential $Credentials -ErrorAction SilentlyContinue) {
    Write-Host 'Saving Back-up of selected tables'

    # Backup Tables (Schema and Data)
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null

    # Array of Tables
    $Tables = @('Hl7IntegrationMaster','IntegrationDistConfig','IntegrationMapping','L2LConfigurations','VaRules','W700Applications','W700Jobs','W700Properties')

    # Output File
    $InsertScriptFile_PK = ".\$($Database)_PK.sql"
    $InsertScriptFile_FK = ".\$($Database)_FK.sql"

    while(Test-Path -Path $InsertScriptFile_PK) {
        try {
            Remove-Item -Path $InsertScriptFile_PK -Force -ErrorAction Stop
        }
        catch {}
    }

    # Target Database Server
    $Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$ServerInstance"

    # Target Database
    $DatabaseObject = $Server.databases["$Database"]

    # New Scripter Object
    $TableScripter = New-Object ('Microsoft.SqlServer.Management.Smo.Scripter')($Server)

    # Define options for the Scripter
    $TableScripter.Options.ScriptData = $True
    $TableScripter.Options.ScriptSchema = $False
    $TableScripter.Options.AppendToFile = $True
    $TableScripter.Options.AllowSystemObjects = $False
    $TableScripter.Options.ClusteredIndexes = $True
    $TableScripter.Options.Indexes = $True
    $TableScripter.Options.ToFileOnly = $True
    $TableScripter.Options.Filename = $InsertScriptFile_PK

    # Build out the Script for each Table in the PK Array
    foreach ($Table in $Tables)
    {
        $TableScripter.enumscript(@($DatabaseObject.tables[$Table]))
    }


    # Backup ExtAttrValue
    $ExtAttrValue = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "SELECT * from VaEntityExtAttributes WHERE ExtAttrName LIKE '%External.AppAuthenticationConfig%'" | Select-Object -ExpandProperty ExtAttrValue
    $ExtAttrValue2 = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "SELECT * from VaEntityExtAttributes WHERE ExtAttrName LIKE '%External.AppAuthenticationConfig%'" | Select-Object -ExpandProperty ExtAttrValue2

    # Backup Database
    Write-Host "Saving Backup of Database $Database"
    Backup-SqlDatabase -ServerInstance "$ServerInstance" -Database "$Database" -BackupFile "\\$ServerInstance\d$\SQL-DB-BACKUP\$Database.bak" -Credential $Credentials

    # Drop Database
    Write-Host "Dropping Database $Database"
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials -Query "DECLARE @kill varchar(8000) = ''; SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id  = db_id('$Database') AND is_user_process = 1; EXEC(@kill);  "
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials -Query " DROP DATABASE [$Database];"
}
else {
    Write-Host "Database doesn't exist."

    $InsertScriptFile_PK = ''
    $InsertScriptFile_FK = ''
    $ExtAttrValue = '-'
    $ExtAttrValue2 = '-'
}

# Restore Database
$DataTable = Invoke-Sqlcmd -ServerInstance $ServerInstance -Username "$Username" -Password "$Password" "restore filelistonly from disk='$BackupFile'"

foreach ($r in $DataTable)
{
    if ($r.Type -eq "L")
    {
        $LogFileLogicalName = $r.LogicalName
    }
    elseif ($r.Type -eq "D")
    {
        if($DataFileLogicalName1 -eq "") {
            $DataFileLogicalName1 = $r.LogicalName
        }
        else {
            $DataFileLogicalName2 = $r.LogicalName
        }
    }
    elseif ($r.Type -eq "S") {
        $MemoryFileLogicalName = $r.LogicalName
    }
}

# Data File, Log File, Memory File Names
$DataFile = "$DataPath\$Database.mdf"
$DataFile2 = "$DataPath\$Database" + "_2.mdf"
$LogFile = "$LogPath\$Database.ldf"
$MemoryFile = "$MemoryPath\$Database" + "_InMem"
#$MemoryFile = "$MemoryPath\$MemoryFileLogicalName"


# Restore Database
$RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($DataFileLogicalName1, $DataFile)
$RelocateData2 = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($DataFileLogicalName2, $DataFile2)
$RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($LogFileLogicalName, $LogFile)
if($MemoryFileLogicalName.length -gt 0) {
    # Restore data, log, memory
    $RelocateMemory = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($MemoryFileLogicalName, $MemoryFile)

    if($DataFileLogicalName2.length -gt 0) {
        Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database $Database -Credential $Credentials -BackupFile $BackupFile -RelocateFile @($RelocateData,$RelocateData2,$RelocateLog, $RelocateMemory)
    }
    else {
        Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database $Database -Credential $Credentials -BackupFile $BackupFile -RelocateFile @($RelocateData,$RelocateLog, $RelocateMemory)
    }
}
else {
    # Restore data, log
    if($DataFileLogicalName2.length -gt 0) {
        Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database $Database -Credential $Credentials -BackupFile $BackupFile -RelocateFile @($RelocateData,$RelocateData2,$RelocateLog)
    }
    else {
        Restore-SqlDatabase -ServerInstance "$ServerInstance" -Database $Database -Credential $Credentials -BackupFile $BackupFile -RelocateFile @($RelocateData,$RelocateLog)
    }
}

Write-Host "Database $Database Restored Successfully"
Write-Host ""



if($InsertScriptFile_FK -ne '') {
    Write-Host 'Saving Back-up of selected tables (Foreign_Key Tables)'
    # Backup Tables (Schema and Data)
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null

    # Array of Tables
    $TablesFK = @('AssociatedAccounts','VaIntRecipient')

    # Output File
    $InsertScriptFile_FK = ".\$($Database)_FK.sql"

    while(Test-Path -Path $InsertScriptFile_FK) {
        try {
            Remove-Item -Path $InsertScriptFile_FK -Force -ErrorAction Stop
        }
        catch {}
    }

    # Target Database Server
    $Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$ServerInstance"

    # Target Database
    $DatabaseObject = $Server.databases["$Database"]

    # New Scripter Object
    $TableScripter = New-Object ('Microsoft.SqlServer.Management.Smo.Scripter')($Server)

    # Define options for the Scripter
    $TableScripter.Options.ScriptData = $True
    $TableScripter.Options.ScriptSchema = $False
    $TableScripter.Options.AppendToFile = $True
    $TableScripter.Options.AllowSystemObjects = $False
    $TableScripter.Options.ClusteredIndexes = $True
    $TableScripter.Options.Indexes = $True
    $TableScripter.Options.ToFileOnly = $True
    $TableScripter.Options.Filename = $InsertScriptFile_FK

    # Build out the Script for each Table in the FK Array
    foreach ($Table in $TablesFK)
    {
        $TableScripter.enumscript(@($DatabaseObject.tables[$Table]))
    }
}



if($ExtAttrValue -ne '-') {
    # Restore ExtAttrValue
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "UPDATE VaEntityExtAttributes SET ExtAttrValue = '$ExtAttrValue' WHERE ExtAttrName = 'External.AppAuthenticationConfig'"
}
if($ExtAttrValue2 -ne '-') {
    # Restore ExtAttrValue2
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "UPDATE VaEntityExtAttributes SET ExtAttrValue2 = '$ExtAttrValue2' WHERE ExtAttrName = 'External.AppAuthenticationConfig'"
}



# Add SQL Users
$NewDBUser = ($Database -Replace("-", "")) +'_RO'
$Password = "Va@2021"
$Database = $Database


$Mastersql = @"
USE [master]
GO
CREATE LOGIN [$NewDBUser] WITH PASSWORD='$Password', DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
"@

$DBsql = @"
USE [$Database]
GO
CREATE USER [$NewDBUser] FOR LOGIN [$NewDBUser] WITH DEFAULT_SCHEMA=[dbo]
EXEC sp_addrolemember 'db_datareader', '$NewDBUser'
GO
"@

if(Get-SqlLogin -ServerInstance "$ServerInstance" -Credential $Credentials  -LoginName "$NewDBUser" -ErrorAction SilentlyContinue) {
    Write-Host "$NewDBUser Exists"

    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "CREATE USER [$($NewDBUser.Split('_')[0])] FROM LOGIN [$($NewDBUser.Split('_')[0])];EXEC sp_addrolemember 'db_owner', '$($NewDBUser.Split('_')[0])';"
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "CREATE USER [$NewDBUser] FROM LOGIN [$NewDBUser];EXEC sp_addrolemember 'db_datareader', '$NewDBUser';"
}
else {
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $Mastersql
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $DBsql
}


$NewDBUser = $Database -Replace("-", "")
$Password = "Star@2021"
$Database = $Database


$Mastersql = @"
USE [master]
GO
CREATE LOGIN [$NewDBUser] WITH PASSWORD='$Password', DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
"@


$DBsql = @"
USE [$Database]
GO
CREATE USER [$NewDBUser] FOR LOGIN [$NewDBUser] WITH DEFAULT_SCHEMA=[dbo]
EXEC sp_addrolemember 'db_owner', '$NewDBUser'
GO
"@


if(Get-SqlLogin -ServerInstance "$ServerInstance" -Credential $Credentials  -LoginName "$NewDBUser" -ErrorAction SilentlyContinue) {
    Write-Host "$NewDBUser Exists"
}
else {
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $Mastersql
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $DBsql
} 


# Set System Base Path
$SystemBasepath                = "\\192.168.168.115\Website-Files\VitalAxis-IIS\$Database\"
$SystemScheduledReportBasePath = "\\192.168.168.115\Website-Files\VitalAxis-IIS\$Database\WS\"
$VOBasePath                    = "\\192.168.168.115\Website-Files\VitalAxis-IIS\$Database\Attachments\"


# Script to change the Basepath, ScheduledReportBasePath, VaRules Status in Database
$BasePathsql = @"
USE [$Database]
GO
UPDATE VaEntityExtAttributes SET ExtAttrValue='$SystemBasepath' WHERE ExtAttrName = 'System.BasePath'
GO
UPDATE VaEntityExtAttributes SET ExtAttrValue='$SystemScheduledReportBasePath' WHERE ExtAttrName = 'System.ScheduledReportBasePath'
GO
UPDATE VaEntityExtAttributes SET ExtAttrValue='$VOBasePath' WHERE ExtAttrName = 'VOBasePath'
GO

UPDATE VaEntityExtAttributes SET ExtAttrValue2 = '$($Database.Replace('-', '').ToLower()).vitalaxis.com' WHERE ExtAttrName='System.DeploymentID'
GO
UPDATE Organizations SET IsADEnabled = 0 WHERE IsADEnabled=1
GO
UPDATE VaEntityExtAttributes SET ExtAttrValue='false' WHERE ExtAttrName ='enable.user_auth_3'
GO

--UPDATE VaRules SET status=2 WHERE status=1
--GO

UPDATE VaEntityExtAttributes SET ExtAttrValue='false' WHERE ExtAttrName = 'Enable.APIReportGeneration'
GO
"@


# Script to Enable Service Broker in Database
$ServiceBroker = @"
USE [$Database]
GO
ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
ALTER DATABASE [$Database] SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE
GO
ALTER DATABASE [$Database] SET NEW_BROKER WITH ROLLBACK IMMEDIATE
GO
ALTER DATABASE [$Database] SET MULTI_USER WITH ROLLBACK IMMEDIATE
GO
"@

# Script to Remove Production URLs in Database
$ProdUrl = @"
USE [$Database]

UPDATE VaIntEvent SET EventData = NULL WHERE EVENTDATA IS NOT NULL

UPDATE Integrationmapping SET lookupValue = NULL WHERE (lookupValue LIKE '%http%' OR lookupValue LIKE '%https%' OR lookupValue LIKE '%FTP/SFTP%')
UPDATE Integrationmapping SET lookupId = NULL WHERE (lookupId LIKE '%http%' OR lookupId LIKE '%https%' OR lookupId LIKE '%FTP/SFTP%')

--UPDATE Integrationmapping SET lookupValue = NULL WHERE LEN(lookupValue) - LEN(REPLACE(LookupValue, '.', '')) = 3  AND lookupValue NOT LIKE '%[^.0-9]%'   -- We need to verify for IPAddress
--UPDATE Integrationmapping SET lookupId = NULL WHERE LEN(LookupId) - LEN(REPLACE(LookupId, '.', '')) = 3  AND lookupId NOT LIKE '%[^.0-9]%'   -- We need to verify for IPAddress

UPDATE Integrationmapping SET LookupValue = NULL 
WHERE  (CASE WHEN 
    (PARSENAME(LookupValue,1) NOT LIKE '%[^0-9]%' OR PARSENAME(LookupValue,1) = '*') AND
    (PARSENAME(LookupValue,2) NOT LIKE '%[^0-9]%' OR PARSENAME(LookupValue,2) = '*') AND
    (PARSENAME(LookupValue,3) NOT LIKE '%[^0-9]%' OR PARSENAME(LookupValue,3) = '*') AND
    (PARSENAME(LookupValue,4) NOT LIKE '%[^0-9]%' OR PARSENAME(LookupValue,4) = '*')
THEN 1 ELSE 0 END = 1)


--UPDATE Integrationmapping SET PropertyValue =    -- We need to verify for Users, Passwords, Agent
UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '%user%'
UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '%orderingphysician%'
UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '%PhysicianCode%'
UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '%Password%'
UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '%ReportFolder_NoAgent%'
UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '%agent%'
UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '%api%'

UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '%\%'
UPDATE Integrationmapping SET LookupValue = NULL WHERE lookupType like '/%'

UPDATE Hl7IntegrationMaster SET localOutboundFolder = NULL, localOutboundBckFolder = NULL, localSourceFolder = NULL, localProcessingFolder = NULL, localFailedFolder = NULL, localSuccessFolder = NULL, localIgnoredFolder = NULL 

UPDATE Hl7IntegrationMaster  SET groupId = '' WHERE Type = 'VitalCore'

UPDATE W700Properties SET PropertyValue = NULL WHERE (PropertyValue LIKE '%http%' OR PropertyValue LIKE '%https%' OR PropertyValue LIKE '%FTP/SFTP%')

--UPDATE W700Properties SET PropertyValue =    -- We need to verify for IPAddress
UPDATE W700Properties SET PropertyValue = NULL 
where  (CASE WHEN 
    (PARSENAME(PropertyValue,1) NOT LIKE '%[^0-9]%' OR PARSENAME(PropertyValue,1) = '*') AND
    (PARSENAME(PropertyValue,2) NOT LIKE '%[^0-9]%' OR PARSENAME(PropertyValue,2) = '*') AND
    (PARSENAME(PropertyValue,3) NOT LIKE '%[^0-9]%' OR PARSENAME(PropertyValue,3) = '*') AND
    (PARSENAME(PropertyValue,4) NOT LIKE '%[^0-9]%' OR PARSENAME(PropertyValue,4) = '*')
THEN 1 ELSE 0 END = 1)

--UPDATE W700Properties SET PropertyValue =    -- We need to verify for Users, Passwords, Agent
UPDATE W700Properties SET PropertyValue = NULL WHERE PropertyKey LIKE '%password%'
UPDATE W700Properties SET PropertyValue = NULL WHERE PropertyKey LIKE '%agent%'
UPDATE W700Properties SET PropertyValue = NULL WHERE PropertyKey LIKE '%API%'
UPDATE W700Properties SET PropertyValue = NULL WHERE PropertyKey LIKE '%user%'

UPDATE W700Properties SET PropertyValue = NULL WHERE Propertyvalue LIKE '\%'
UPDATE W700Properties SET PropertyValue = NULL WHERE Propertyvalue LIKE '/%'


UPDATE DistributionBatches SET Recipient = NULL, Data = NULL 
UPDATE HL7Integrationlog SET handlerdata = NULL, handlerdata2 = NULL 
 

UPDATE VaEntityExtAttributes SET ExtAttrValue = NULL,ExtAttrValue2 = NULL
WHERE ExtAttrName IN  ('zebra_archive_folder','zebra_destination_folder',
'zebra_jar_label_archive_folder','zebra_jar_label_destination_folder',
'zebra_jar_label_local_temp_folder','zebra_jar_label_template_file',
'zebra_local_temp_folder','zebra_template_file','network_printer_output_folder',
'cassette_archive_folder_name','cassette_dest_folder_name','cassette_local_temp_folder_name',
'leica_cassette_local_temp_folder','leica_slide_local_temp_folder')
"@

# Script to set to false the enable.user_auth_3 in Database
$UserAuth = @"
USE [$Database]
GO
UPDATE VaEntityExtAttributes SET ExtAttrValue='false' WHERE ExtAttrName='enable.user_auth_3'
GO
"@


$UserMapping = @"
USE [$Database]
GO
USE [$Database]
GO
UPDATE Organizations SET IsADEnabled=0 WHERE IsADEnabled=1
GO
USE [$Database]
GO
UPDATE VaEntityExtAttributes SET ExtAttrValue='false' WHERE ExtAttrName ='enable.user_auth_3'
GO
"@

Write-Host 'Updating BasePath'
Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $BasePathsql

Write-Host 'Enabling ServiceBroker'
Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $ServiceBroker -ErrorAction Continue

Write-Host 'Removing Prod URLs'
Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $ProdUrl

Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $UserAuth
Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Credential $Credentials  $UserMapping




# Script to Truncate data from the list of tables backed up before deleting old database
$DropScript = @"
--TRUNCATE TABLE [Hl7IntegrationMaster]
TRUNCATE TABLE [IntegrationDistConfig]
--TRUNCATE TABLE [VaEntityExtAttributes]
DELETE FROM [Hl7IntegrationMaster]
TRUNCATE TABLE [IntegrationMapping]
TRUNCATE TABLE AssociatedAccounts
--TRUNCATE TABLE [L2Lconfigurations]
DELETE FROM [L2Lconfigurations]
--TRUNCATE TABLE [VaRules]
TRUNCATE TABLE VaIntRecipient
DELETE FROM [VaRules]
TRUNCATE TABLE [W700Jobs]
--TRUNCATE TABLE [W700Applications]
DELETE FROM [W700Applications]
TRUNCATE TABLE [W700Properties]
"@

$FK_DisableTrigger = @"
ALTER TABLE [AssociatedAccounts] DISABLE TRIGGER [AssociatedAccounts_AspNet_SqlCacheNotification_Trigger]
ALTER TABLE [AssociatedAccounts] DISABLE TRIGGER [OWNERSLABUPDATETRIGGER]
GO
"@

$FK_EnableTrigger = @"
ALTER TABLE [AssociatedAccounts] ENABLE TRIGGER [AssociatedAccounts_AspNet_SqlCacheNotification_Trigger]
ALTER TABLE [AssociatedAccounts] ENABLE TRIGGER [OWNERSLABUPDATETRIGGER]
GO
"@

if($InsertScriptFile_PK -ne '') {
    Write-Host 'Truncating data from the list of tables backed up before deleting old database'
    # Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "$DropScript"

    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "TRUNCATE TABLE [IntegrationDistConfig]"
    # [System.Array] $VaEntityExtAttributes = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "SELECT EntityId, EntityType, ExtAttrName, ExtAttrValue2 FROM VaEntityExtAttributes" | Select-Object -ExpandProperty EntityId
    # foreach($VaEntityExtAttribute in $VaEntityExtAttributes) {
    # 	Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "DELETE FROM VaEntityExtAttributes WHERE EntityId = $VaEntityExtAttribute"
    # }
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "DELETE FROM [Hl7IntegrationMaster]"
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "TRUNCATE TABLE [IntegrationMapping]"
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "TRUNCATE TABLE AssociatedAccounts"
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "DELETE FROM [L2Lconfigurations]"
    Invoke-Sqlcmd -ServerInstance "$ServerInstance" -Database "$Database" -Credential $Credentials -Query "TRUNCATE TABLE VaIntRecipient"
    [System.Array] $VaRules = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "SELECT RuleId, RuleName FROM VaRules" | Select-Object -ExpandProperty RuleId
    foreach($VaRule in $VaRules) {
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "DELETE FROM VaRules WHERE RuleId = $VaRule"
    }
    [System.Array] $W700Jobs = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "SELECT JobId, JobName FROM W700Jobs" | Select-Object -ExpandProperty JobId
    foreach($W700Job in $W700Jobs) {
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "DELETE FROM W700Jobs WHERE JobId = $W700Job"
    }
    [System.Array] $W700Applications = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "SELECT ApplicationId, Name FROM W700Applications" | Select-Object -ExpandProperty ApplicationId
    foreach($W700Application in $W700Applications) {
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "DELETE FROM W700Applications WHERE ApplicationId = $W700Application"
    }
    [System.Array] $W700Properties = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "SELECT PropertyId, OwnerId, OwnerType, PrefixType, PropertyKey FROM W700Properties" | Select-Object -ExpandProperty PropertyId
    foreach($W700Property in $W700Properties) {
        try {
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "DELETE FROM W700Properties WHERE PropertyId = $W700Property" -ErrorAction Stop
        }
        catch {
            if($_ -match 'W700PropertiesINSUPDDELTRIGGER') {
                Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "DISABLE TRIGGER W700PropertiesINSUPDDELTRIGGER ON W700Properties;"
                Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "DELETE FROM W700Properties WHERE PropertyId = $W700Property"
                Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query "ENABLE TRIGGER W700PropertiesINSUPDDELTRIGGER ON W700Properties;"
            }
            else {
                $_
            }
        }
    }

    # Execute Generated SQL Script to Insert Backed-up Data 
    Write-Host 'Restoring Backed-up tables'
    Write-Host "(PK = $([Math]::Round((Get-Item -Path $InsertScriptFile_PK).Length / (1024 * 1024), 2)) MB, FK = $([Math]::Round((Get-Item -Path $InsertScriptFile_FK).Length / (1024 * 1024), 2)) MB)"
    
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -DisableVariables -InputFile $InsertScriptFile_PK -ErrorAction SilentlyContinue;

    #Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -DisableVariables -InputFile $FK_DisableTrigger;
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -DisableVariables -InputFile $InsertScriptFile_FK -ErrorAction SilentlyContinue;
    #Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -DisableVariables -InputFile $FK_EnableTrigger;
}




# WorklistIDs
$WorklistIDs = @"
DECLARE @WorklistIDs TABLE(ID BIGINT) 
INSERT INTO @WorklistIDs(ID)
SELECT ID FROM OrganizationCustomWorklist WHERE IsActive=1 AND type='worklist'
UPDATE OrganizationCustomWorklist SET isactive=0 WHERE ID in (SELECT ID FROM @WorklistIDs)
EXEC [dbo].[Job_PopulateCasesWorkList]
UPDATE OrganizationCustomWorklist SET isactive=1 WHERE ID in (SELECT ID FROM @WorklistIDs)
EXEC [dbo].[Job_PopulateCasesWorkList]
"@

Write-Host 'Running WorklistIDs Update Script'
Invoke-Sqlcmd -ServerInstance $ServerInstance -Database "$Database" -Credential $Credentials -Query $WorklistIDs



# Remove VitalAdmin Production URLs
$RemoveVitalAdminURL = "UPDATE Organizations SET AppURL = NULL WHERE isnull(appurl,'') != ''"
Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -Query $RemoveVitalAdminURL




# GUID Masking
Write-Host 'Running GUID Masking Script'
$GuidMaskingScript = Get-Content -Raw -LiteralPath 'D:\VitalAxis\Jenkins_Build\ORION\SQL_Scripts\01.GUID_Masking_Local.sql'
Invoke-Sqlcmd -ServerInstance $ServerInstance -Database "$Database" -Credential $Credentials -Query $GuidMaskingScript



# Execute SQL Script to Update IPCountry
Write-Host 'Running IPCountry Update Script'
Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -InputFile "D:\VitalAxis\Jenkins_Build\ORION\SQL_Scripts\IP_Country.sql"


# Execute SQL Script for AutoOrgCreation
Write-Host 'Running AutoOrgCreation Script'
Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -InputFile "D:\VitalAxis\Jenkins_Build\ORION\SQL_Scripts\AutoOrgCreationScript.sql"



# Execute UpdateReportEventSuccess and Start ETL Jobs
if($Database -in @('TITAN-SPRINT-BCM', 'TITAN-SPRINT-LIS', 'TITAN-SPRINT-MYLIS', 'TITAN-SPRINT-PROGRAMS', 'TITAN-SPRINT-SAGIS', 'TITAN-SPRINT-SOLARIS', 'TITAN-SPRINT-TLA', 'TITAN-SPRINT-UPM', 'TITAN-SPRINT-VPLABS')) {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -InputFile "D:\VitalAxis\Jenkins_Build\ORION\SQL_Scripts\UpdateReportEventSuccess.sql"
    
    $ReportDBDataCleaning = Get-Content -Raw -LiteralPath 'D:\VitalAxis\Jenkins_Build\ORION\SQL_Scripts\ReportDB_DataCleaning.sql'
    $ReportDBDataCleaning = $ReportDBDataCleaning -replace ('[$]DatabaseName', "$($Database -replace ('\w+-\w+-', ''))")
    Invoke-Sqlcmd -ServerInstance '192.168.168.51' -Database 'VaLocal-Reports' -Credential $Credentials -Query $ReportDBDataCleaning

    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Credential $Credentials -InputFile "D:\VitalAxis\Jenkins_Build\ORION\SQL_Scripts\LoadingCases_ReportEvent.sql"

    #Write-Host 'Starting ETL Job'
    #Invoke-Sqlcmd -ServerInstance '192.168.168.51' -Database 'msdb' -Credential $Credentials -Query "EXECUTE sp_update_job @job_name = '$($Database -replace '\w+-\w+-', 'ETL_')', @enabled = 1;" -ErrorAction SilentlyContinue
}
