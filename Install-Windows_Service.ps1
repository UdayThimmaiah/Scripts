# Install Windows Service

$ServiceName = "VA_"
$EXEPath = "D:\VA.exe"

# Install Service
sc.exe create "$ServiceName" start=delayed-auto binpath="$EXEPath"

# Set Logon as Devopsappadmin
sc.exe config "$ServiceName" obj="Devopsappadmin@ad.starmarkit.com" password=""

# Start Service
sc.exe start "$ServiceName"

# #################################################
# Stop Service
# sc.exe stop "$ServiceName"

# Delete Service
# sc.exe delete "$ServiceName"
