# Export and Import all IIS Sites and AppPools
### Export:
inetsrv\appcmd list apppool /config /xml > D:\IIS_AppPools.xml
inetsrv\appcmd list site /config /xml > D:\IIS_Sites.xml

### Import:
inetsrv\appcmd add apppool /in < D:\IIS_AppPools.xml
inetsrv\appcmd add site /in < D:\IIS_Sites.xml