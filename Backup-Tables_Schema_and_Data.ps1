# Backup Tables (Schema and Data)
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null

# DB Server
$ServerInstance = "192.168.168.27"

# Database Name
$DatabaseName = "INT-DEV-LIS"

# Array of Tables
$Tables = @('Hl7IntegrationMaster','IntegrationDistConfig','IntegrationMapping','VaRules','W700Applications','W700Jobs','W700Properties','L2Lconfigurations')

# Output File
$OutFile = "D:\$DatabaseName.sql"


# Target Database Server
$Server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$ServerInstance"

# Target Database
$DatabaseObject = $Server.databases["$DatabaseName"]

# New Scripter Object
$TableScripter = New-Object ('Microsoft.SqlServer.Management.Smo.Scripter')($Server)

# Define options for the Scripter
$TableScripter.Options.ScriptData = $True
$TableScripter.Options.ScriptSchema = $True
$TableScripter.Options.AppendToFile = $True
$TableScripter.Options.AllowSystemObjects = $False
$TableScripter.Options.ClusteredIndexes = $True
$TableScripter.Options.Indexes = $True
$TableScripter.Options.ToFileOnly = $True
$TableScripter.Options.Filename = $OutFile

$DropScript = ''

# Script to Drop existing Tables
foreach ($Table in $Tables)
{
    $DropScript += @"
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[$Table]') AND type in (N'U'))
DROP TABLE [dbo].[$Table]
GO


"@
}

# Build out the Script for each Table in the Array
foreach ($Table in $Tables)
{
    $TableScripter.enumscript(@($DatabaseObject.tables[$Table]))
}

# Concat Drop and Create Scripts
$InsertScript = $DropScript + (Get-Content -Path $OutFile -Raw)

Set-Content -Path $OutFile -Value $InsertScript -Force