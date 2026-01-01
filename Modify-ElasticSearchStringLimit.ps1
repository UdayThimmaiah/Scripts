
$ElasticHost = 'http://192.168.168.68:9205'

# The settings will be stored under a Template with this name
$TemplateName = 'custom_string_max_length'

# List of Field Names and their required sizes
$Fields = @(
  @{Name = 'diagnosisInformation.diagnosisSummary'; Size = 4096},
  @{Name = 'diagnosisInformation.caseCommentCode'; Size = 4096},
  @{Name = 'diagnosisInformation.microscopicCode'; Size = 4096},
  @{Name = 'diagnosisInformation.grossDescription'; Size = 4096},
  @{Name = 'diagnosisInformation.diagattr1'; Size = 2048},
  @{Name = 'diagnosisInformation.diagattr2'; Size = 2048},
  @{Name = 'diagnosisInformation.diagattr3'; Size = 2048},
  @{Name = 'diagnosisInformation.diagattr4'; Size = 2048},
  @{Name = 'diagnosisInformation.diagattr5'; Size = 2048},
  @{Name = 'diagnosisInformation.diagattr6'; Size = 2048},
  @{Name = 'diagnosisInformation.diagattr7'; Size = 2048},
  @{Name = 'diagnosisInformation.diagattr8'; Size = 2048},
  @{Name = 'diagnosisInformation.diagattr9'; Size = 2048}
)

# Dynamically Generate Request Body using above list of Fields
$Properties = ''

foreach($Field in $Fields) {
    $Properties += @"

      "$($Field.Name)": {
        "type": "text",
        "fields": {
          "keyword": {
            "type": "keyword",
            "ignore_above": $($Field.Size)
          }
        }
      },
"@
}

$Properties = $Properties.TrimEnd(',')

# Settings to Set max length limit for selected fields
$Body = @"
{
  "index_patterns": ["*_diagnosis"],
  "mappings": {
    "properties": {
      $Properties
    }
  }
}
"@

# Add Template
Invoke-WebRequest -Method Put -Uri "$ElasticHost/_template/$TemplateName" -Headers @{"Content-Type"="application/json"} -Body $Body

# List All Templates
# (Invoke-WebRequest -Method Get -Uri "$ElasticHost/_template/").Content | ConvertFrom-Json

# Delete Template 
# Invoke-WebRequest -Method Delete -Uri "$ElasticHost/_template/$TemplateName"
