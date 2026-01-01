
$ElasticHost = 'http://192.168.168.68:9205'

# The settings will be stored under a Template with this name
$TemplateName = 'custom_results_max_size'

# Settings to Set max number of data rows that are stored in Elastic Server
$Body = @"
{
  "index_patterns": ["*_diagnosis"],
  "settings": {
    "index.max_result_window": 200000
  }
}
"@

# Add Template
Invoke-WebRequest -Method Put -Uri "$ElasticHost/_template/$TemplateName" -Headers @{"Content-Type"="application/json"} -Body $Body

# List All Templates
# (Invoke-WebRequest -Method Get -Uri "$ElasticHost/_template/").Content | ConvertFrom-Json

# Delete Template 
# Invoke-WebRequest -Method Delete -Uri "$ElasticHost/_template/$TemplateName"
