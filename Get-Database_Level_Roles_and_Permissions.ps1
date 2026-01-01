$DBServer = "192.168.168.26";

$OutputFile = ".\User_Roles_and_Permissions.txt";



$CurrentDirectory = $PSScriptRoot

cd $CurrentDirectory

[System.Array] $DBList = @();

$DBList = Invoke-SqlCmd -ServerInstance $DBServer -Database master -Query "SELECT name FROM sys.databases WHERE name NOT IN ('master', 'msdb', 'tempdb', 'model');"


$Query = @"
-------------------------------Get DataBase level roles and Permissions and Fix the Orphan users-----------------------

SET NOCOUNT ON
print 'Use [' + db_name()+']' 
print 'go'

--Grant DB Access---
print '-->[   Grant DB Access   ]<--'
select 'if not exists (select * from dbo.sysusers where name = N''' + usu.name +''' )' + Char(13) + Char(10) +'         EXEC sp_grantdbaccess N''' + lo.loginname +  '''' + ', N''' + usu.name +  '''' + Char(13) + Char(10) +
'GO' collate database_default
from sysusers usu , master.dbo.syslogins lo
where usu.sid = lo.sid and (usu.islogin = 1 and usu.isaliased = 0 and usu.hasdbaccess = 1)
go

-- User vs Login Mapping  --
print '-->[   User vs Login Mapping]<--'
select 'sp_change_users_login '''+'update_one'''+', '''+name+''', '''+name+''''+char(13)+char(10)+'go' from sysusers 
where uid > 4 
and issqlrole = 0 
and hasdbaccess = 1
and isntname = 0
order by name
go
--Add Roles---
print '-->[    Adding Roles     ]<--'
select 'if not exists (select * from dbo.sysusers where name = N''' + name +''' )' + Char(13) + Char(10) +
'         EXEC sp_addrole N''' + name +  '''' + Char(13) + Char(10) +
'GO'
from sysusers where uid > 0 and uid=gid and issqlrole=1
go
--Add RoleMember---
print '-->[ Adding Role Members ]<--'
select 'exec sp_addrolemember N''' + user_name(groupuid) + ''', N''' + user_name (memberuid) + '''' + Char(13) + Char(10) +
'GO' 
from sysmembers where  user_name (memberuid) <> 'dbo' order by groupuid


--Add Alias Login also---
print '-->[   Add Alias  ]<--'
select 'if not exists (select * from dbo.sysusers where name = N''' + a.name +''' )' + Char(13) + Char(10) +
'         EXEC sp_addalias N''' + substring(a.name , 2, len(a.name)) +  '''' + ', N''' + b.name +  '''' + Char(13) + Char(10) +
'GO'
from sysusers a , sysusers b where a.altuid = b.uid and a.isaliased=1
go
SET NOCOUNT OFF
"@


foreach($Database in $DBList){
    [System.Array] $Output = Invoke-SqlCmd -ServerInstance $DBServer -Database $Database.name -Query $Query;

    # $Output = $Output -replace ('(?ms)(-->\[\s*Add Alias\s*\]<--)(\s*-+\s*)*(Completion time:\s*.*?$)', '');
    "USE [$($Database.name)]" >> $OutputFile;
    "GO" >> $OutputFile;
    "" >> $OutputFile;
    foreach($Row in $Output){ 
        $Row[0] = $Row[0] -replace ('(?m)(^\s*--.*$)', '');
        Write-Host $Row[0];
        $Row[0] >> $OutputFile;
    }
    "-------------------------------------------------" >> $OutputFile;
    "-------------------------------------------------" >> $OutputFile;
}

Write-Host ""
Write-Host "Output Saved to $CurrentDirectory\$($OutputFile.Trim(".\"))"
