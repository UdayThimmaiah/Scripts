
$RundeckDBServer = "192.168.168.114"
$RundeckDBName = "rundeck"
$RundeckAPI = "http://selfserve.vitalaxis.com:4440/api/14";
$RundeckAPIKey = "5FY0PaI94HzLo8K0uGUgH1DXoJ9l3KaM";

$OutputFilePath = "D:\RunDeck_Job_History.csv";


# Query to fetch all executions from Rundeck database
$Query = @"
SELECT id AS execution_id, '' AS job_id, '' AS job_name, '' AS last_run, status, project, date_completed, left(outputfilepath, len(outputfilepath) - charindex('\', reverse(outputfilepath) + '\')) AS outputfilepath
FROM dbo.execution
WHERE date_completed >= DATEADD(month, -3, GETDATE())
ORDER BY outputfilepath, date_completed
"@

[System.Array] $Results = Invoke-Sqlcmd -ServerInstance $RundeckDBServer -Database $RundeckDBName -Query "$Query";
[System.Array] $ExecutionLog = @();
[System.Array] $JobExecutionLog = @();

foreach($Result in $Results){
    # Get only "Job" executions and ignore "Command" executions
    if($Result.outputfilepath.Contains("\job\")){
        $Result.job_id = $Result.outputfilepath -replace('(^.*?\\job\\)([^\\]+)(\\.*$)', '$2');
        $ExecutionLog += $Result;
    }
}

for($i = 0; $i -lt $ExecutionLog.Length; $i++){
    if($ExecutionLog[$i].job_id -eq $ExecutionLog[$i + 1].job_id){
        # Execution of same job; Consider only the last entry (Sorted by date) to get the most recent execution of that job.
        continue;
    }

    try{
        # Get Job name using Rundeck API. Requires active API token.
        $JobInfo = Invoke-WebRequest -Uri "$RundeckAPI/job/$($ExecutionLog[$i].job_id)" -Headers @{ "X-Rundeck-Auth-Token" = $RundeckAPIKey; "Accept" = "text/yaml" };
        $JobName = $JobInfo.Content -replace ('(?ms)(.*?^\s*name: )(.*?)$(.*)', '$2');
    }
    catch{
        $JobName = "---";
    }

    # Calculate N in "Last run N days ago"
    $LastRun = (New-TimeSpan -Start (Get-Date $ExecutionLog[$i].date_completed -Format "yyyy-MM-dd") -End (Get-Date -Format "yyyy-MM-dd")).Days;

    $ExecutionLog[$i].job_name = "$JobName";
    $ExecutionLog[$i].last_run = "" + $LastRun + " Days Ago";

    $ExecutionLog[$i].outputfilepath = "" + $ExecutionLog[$i].outputfilepath + "\" + $ExecutionLog[$i].execution_id + ".rdlog";

    $JobExecutionLog += $ExecutionLog[$i];
}

Write-Host "JobExecutionLog.Length = $($JobExecutionLog.Length)";
$JobExecutionLog | Export-csv -Path "$OutputFilePath" -NoTypeInformation -Force
