
$OutputFile = 'D:\JenkinsJobsHistory.csv'

$JenkinsRoot = 'C:\ProgramData\Jenkins\.jenkins\jobs'

$DateRange = (Get-Date).AddMonths(-3)

$AllJenkinsFolders = Get-ChildItem -Directory -Recurse -Path $JenkinsRoot -Force

$JenkinsJobs = @()

foreach($JenkinsFolder in $AllJenkinsFolders){
    if(Test-Path -Path "$($JenkinsFolder.FullName)\builds"){
        Write-Host "$($JenkinsFolder.Name)..."

        [System.Array] $Builds = @()
        [System.Array] $Builds = Get-ChildItem -Directory -Path "$($JenkinsFolder.FullName)\builds" | Where LastWriteTime -ge $DateRange

        foreach($Build in $Builds){
            $JenkinsJobs += New-Object -TypeName PSObject -Property $([ordered]@{JobName=$JenkinsFolder.Name; JobPath=$JenkinsFolder.FullName.Replace($JenkinsRoot, ''); BuildId=$Build.Name; BuildDate=$Build.LastWriteTime;})
        }
    
    }
}

Write-Host ''
$JenkinsJobs | Format-Table

$JenkinsJobs | Export-Csv -Path $OutputFile -NoTypeInformation
Write-Host "Output saved to $OutputFile"
