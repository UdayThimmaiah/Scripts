
#*********************************************************************
Get-Content "$PSScriptRoot\WinSerPropertyFile.txt" | ForEach-Object -Begin {$settings=@{}} -Process {$store = [regex]::split($_,'='); if(($store[0].CompareTo("") -ne 0) -and ($store[0].StartsWith("[") -ne $True) -and ($store[0].StartsWith("#") -ne $True)) {$settings.Add($store[0], $store[1])}}
$Team = $settings.Get_Item("Team").ToUpper()
$DeploymentName = $settings.Get_Item("DeploymentName").ToUpper()
$Environment = $settings.Get_Item("Environment").ToUpper()
$GITbranch = $settings.Get_Item("Gitbranch")
$MainUrl = $settings.Get_Item("MainUrl")
$APIUrl = $settings.Get_Item("APIUrl")
$DBServername = $settings.Get_Item("DbServername")
$DBNAME = $settings.Get_Item("DBname")
$DBUser = $settings.Get_Item("DBUser")
$DBPassword = $settings.Get_Item("DBPassword")
$SourceIISPath = $settings.Get_Item("SourceIISPath")
$SourceReportPath = $settings.Get_Item("SourcePDFFilesPath")
$ElasticServer = $settings.Get_Item("ElasticServer")
$GWSBPPUrl = $settings.Get_Item("PRINTTECHSHEET_URL")
$DBNAMEDest = $settings.Get_Item("DestinationDBName")
$DBUserDest = $settings.Get_Item("DestinationDBUser")
$DBPasswordDest = $settings.Get_Item("DestinationDBPassword")
$DestinationReportPath = $settings.Get_Item("DestinationPDFFilesPath")
$MSBuildPath = $settings.Get_Item("MSBuildPath")

$MainScriptpath = $PSScriptRoot
$GITBuildSpace = New-Item -Path "$MainScriptpath" -Name "CloneSpace" -ItemType "Directory"
$GitSource = New-Item -Path "$GITBuildSpace" -Name "src" -ItemType "Directory"
$GitOut = New-Item -Path "$MainScriptpath" -Name "InstallFiles" -ItemType "Directory"
$LogFolder = New-Item -Path "$MainScriptpath" -Name "InstallLogs" -ItemType "Directory"

$ServiceListFile = "$MainScriptpath\ServiceList.txt"

#Clean the Uninstall file content
Clear-Content -Path "$MainScriptpath\UninstallServices.ps1"
Clear-Content -Path "$MainScriptpath\Log\MainLog.log"
Clear-Content -Path "$MainScriptpath\ServiceList.txt"

&{

    Write-Host "**************************************************************************" -ForegroundColor BLACK -BackgroundColor GREEN
    Write-Host "Welcome to VITALDX Windows Service Installation Automation"
    Write-Host "Project Git Clone Branch = $GITbranch"
    Write-Host "**************************************************************************" -ForegroundColor BLACK -BackgroundColor GREEN
    Write-Output "**************************************************************************" 
    Write-Output "Project Git Clone Branch = $GITbranch"
    Write-Output "**************************************************************************"
    
    #Git Clone Command.
    #$gitsoft="C:\Program Files\Git\git-cmd.exe"
    try
    {
        cmd.exe /c git clone -b $GITbranch http://lohith.jayanna:Yy9v4R8WLmuq_xgygE_k@vagit.vitalaxis.com/vitalaxis/VAWindowsServices.git/  $GitSource
        Write-Host "Git Clone Success"
        Write-Output "Git Clone Success"
    }
    catch
    {
        Write-Host "Git Clone Failure"
        Write-Output "Git Clone Failure"
        Write-Output "$_"
        Exit
    }

    #Each Build to output directory
    # $Folders = Get-ChildItem -Path $GitSource -Directory
    [System.Array] $Folders = @('ElasticsSearch', 'ScheduledReportService', 'VitalLogExport', 'VAUploadFileToAzure');
    foreach ($Folder in $Folders)
    {
        # Write-Host $Folder.name
        # Creating Output Directory for MSBUILD
        $BuildOutput = New-Item -Path "$GitOut" -Name "$Folder" -ItemType "Directory"

        # Finding *.sln File names to supply to MS build
        $SLNFiles = Get-ChildItem -Path $GitSource\$Folder -Recurse -ErrorAction SilentlyContinue -Filter *.sln | Where-Object { $_.Extension -eq '.sln' } 
        # Command to BUILD The sln
        Write-Host "**************************************************************************" -ForegroundColor BLACK -BackgroundColor BLUE
        Write-Host "BUILD Project Name = $Folder and BUILD Sln File = $SLNFiles"
        Write-Host "**************************************************************************" -ForegroundColor BLACK -BackgroundColor BLUE
        Write-Output "**************************************************************************" 
        Write-Output "BUILD Project Name = $Folder"
        Write-Output "**************************************************************************"
        $nugetFile="$MainScriptpath\bin\nuget.exe"
        & $nugetFile restore "$GitSource\$Folder\$SLNFiles"
        cmd.exe /c "$MSBuildPath" "$GitSource\$Folder\$SLNFiles" /target:Build  "/p:Configuration=Release;OutDir=$BuildOutput"
    }

    #Each Build to output directory
    $InstallFolders = Get-ChildItem -Path $GitOut -Directory
    foreach ($InstallFolder in $InstallFolders)
    {
        Write-Output "**************************************************************************" 
        Write-Output "$InstallFolder Service installation"
        Write-Output "**************************************************************************"

        # CALL EACH FILE FOR BUILD AND INSTALL       
        & "$PSScriptRoot\BuildFiles\$InstallFolder.ps1"
    }

    #Move the install.bat to bin folder
    Move-Item -Path "$MainScriptpath\WinSer_INSTALL.bat" -Destination "$MainScriptpath\bin" -Force


} 3>&1 2>&1 > "$MainScriptpath\Log\MainLog.log"
