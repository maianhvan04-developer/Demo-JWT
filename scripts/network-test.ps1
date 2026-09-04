$ErrorActionPreference = "Stop"
$script:Passed = 0
$script:Failed = 0

function Assert-Check([string]$name, [bool]$condition, [string]$detail) {
  if ($condition) {
    $script:Passed++
    Write-Host "PASS | $name | $detail" -ForegroundColor Green
  } else {
    $script:Failed++
    Write-Host "FAIL | $name | $detail" -ForegroundColor Red
  }
}

function Get-NetworkContainers([string]$network) {
  $json = @(& docker network inspect $network) -join "`n"
  if ($LASTEXITCODE -ne 0) { throw "Cannot inspect network $network" }
  $result = $json | ConvertFrom-Json
  @($result[0].Containers.PSObject.Properties | ForEach-Object { $_.Value.Name })
}

$edge = Get-NetworkContainers "jwt-demo-edge"
$data = Get-NetworkContainers "jwt-demo-data"

Write-Host "edge: $($edge -join ', ')"
Write-Host "data: $($data -join ', ')"

Assert-Check "Gateway nam trong edge" ($edge -contains "jwt-demo-api-gateway") "expected member"
Assert-Check "Finance API nam trong edge" ($edge -contains "jwt-demo-finance-api") "expected member"
Assert-Check "PostgreSQL khong nam trong edge" ($edge -notcontains "jwt-demo-postgres") "database isolated"
Assert-Check "PostgreSQL nam trong data" ($data -contains "jwt-demo-postgres") "expected member"
Assert-Check "Gateway khong nam trong data" ($data -notcontains "jwt-demo-api-gateway") "no direct DB network"

& docker compose exec -T api-gateway node -e "fetch('http://finance-api:4000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
Assert-Check "Gateway ket noi duoc Finance API" ($LASTEXITCODE -eq 0) "edge communication"

& docker compose exec -T api-gateway node -e "require('node:dns').promises.lookup('postgres').then(()=>process.exit(1)).catch(()=>process.exit(0))"
Assert-Check "Gateway khong phan giai duoc PostgreSQL" ($LASTEXITCODE -eq 0) "data boundary enforced"

$uid = @(& docker compose exec -T finance-api id -u)[0].Trim()
Assert-Check "Finance API khong chay bang root" ($uid -ne "0") "uid=$uid"

Write-Host "`nKET QUA NETWORK: PASS=$($script:Passed) FAIL=$($script:Failed)" -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Red" })
if ($script:Failed -gt 0) { exit 1 }
