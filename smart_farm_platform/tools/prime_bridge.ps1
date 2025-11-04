$ErrorActionPreference='Stop'
$base='https://smart-farm-api-g25w.onrender.com/api'
try {
  $all = Invoke-RestMethod -Uri "$base/all" -TimeoutSec 30
} catch { Write-Output "ERROR fetching /api/all: $_"; exit 1 }
$keys = $all.PSObject.Properties | ForEach-Object { $_.Name }
$results = @()
foreach ($k in $keys) {
  $group = ($k -split '_')[0]
  $candidates = @()
  $candidates += $k
  if ($k -match '_') {
    $tail = ($k -split '_')[-1]
    $candidates += $tail
    $candidates += "g$tail"
    $candidates += "G$tail"
    $candidates += "${group}_$tail"
  }
  $candidates += 'DEFAULT','default','telemetry', "${group}_telemetry",'1','2','3'
  $candidates = $candidates | Select-Object -Unique
  foreach ($cand in $candidates) {
    try {
      $uri = "$base/force_refresh/$group/$cand"
      $r = Invoke-RestMethod -Method Post -Uri $uri -TimeoutSec 30
      $results += [PSCustomObject]@{key=$k; group=$group; candidate=$cand; success=$true; message=($r -as [string])}
    } catch {
      $results += [PSCustomObject]@{key=$k; group=$group; candidate=$cand; success=$false; message=$_.Exception.Message}
    }
  }
}
$summary = $results | Group-Object -Property key | ForEach-Object {
  [PSCustomObject]@{key=$_.Name; attempts=($_.Group | Measure-Object).Count; successes=($_.Group | Where-Object { $_.success } | Measure-Object).Count; details=$_.Group}
}
$out = @{timestamp=(Get-Date).ToString('o'); base=$base; summary=$summary; raw=$results}
$out | ConvertTo-Json -Depth 5
