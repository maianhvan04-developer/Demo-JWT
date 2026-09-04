$ErrorActionPreference = "Stop"
$Base = if ($env:GATEWAY_URL) { $env:GATEWAY_URL } else { "http://localhost:3000" }
$KC = if ($env:KEYCLOAK_URL) { $env:KEYCLOAK_URL } else { "http://localhost:8080" }
$script:Passed = 0
$script:Failed = 0

function Get-Token($realm, $client, $username, $password) {
  Invoke-RestMethod -Method Post `
    -Uri "$KC/realms/$realm/protocol/openid-connect/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body @{ grant_type="password"; client_id=$client; username=$username; password=$password }
}

function Invoke-Case($name, [int]$expected, [string[]]$curlArgs) {
  Write-Host "`n============================================================" -ForegroundColor DarkGray
  Write-Host "$name | expected=$expected" -ForegroundColor Cyan
  Write-Host "============================================================" -ForegroundColor DarkGray

  $responseLines = @(& curl.exe -sS -i @curlArgs)
  $curlExit = $LASTEXITCODE
  $responseLines | ForEach-Object { Write-Host $_ }

  $status = 0
  if ($curlExit -eq 0 -and $responseLines.Count -gt 0 -and $responseLines[0] -match '^HTTP/\S+\s+(\d{3})') {
    $status = [int]$Matches[1]
  }

  if ($status -eq $expected) {
    $script:Passed++
    Write-Host "PASS | actual=$status" -ForegroundColor Green
  } else {
    $script:Failed++
    Write-Host "FAIL | expected=$expected actual=$status curlExit=$curlExit" -ForegroundColor Red
  }
}

Write-Host "Preflight: kiem tra toan bo dependency qua API Gateway..." -ForegroundColor Green
Invoke-Case "PRE01 - Gateway + Finance API + PostgreSQL healthy" 200 @("$Base/health")

Write-Host "`nLay token demo tu Keycloak..." -ForegroundColor Green
$alice = Get-Token "finance-lab" "lab-client" "alice" "Alice@123"
$bob = Get-Token "finance-lab" "lab-client" "bob" "Bob@123"
$wrongAud = Get-Token "finance-lab" "wrong-audience-client" "alice" "Alice@123"
$wrongIssuer = Get-Token "other-lab" "other-client" "eve" "Eve@123"

$aliceHeader = "Authorization: Bearer $($alice.access_token)"
$bobHeader = "Authorization: Bearer $($bob.access_token)"
$wrongAudHeader = "Authorization: Bearer $($wrongAud.access_token)"
$wrongIssuerHeader = "Authorization: Bearer $($wrongIssuer.access_token)"
$refreshHeader = "Authorization: Bearer $($alice.refresh_token)"

Invoke-Case "TC01 - Khong co token" 401 @("$Base/api/finance/accounts")
Invoke-Case "TC02 - Alice token hop le + finance.read" 200 @("-H", $aliceHeader, "$Base/api/finance/accounts")
Invoke-Case "TC03 - Bob token hop le nhung thieu role" 403 @("-H", $bobHeader, "$Base/api/finance/accounts")
Invoke-Case "TC04 - Sai audience" 401 @("-H", $wrongAudHeader, "$Base/api/finance/accounts")
Invoke-Case "TC05 - Token tu realm/issuer khac" 401 @("-H", $wrongIssuerHeader, "$Base/api/finance/accounts")
Invoke-Case "TC06 - JWT sai dinh dang" 401 @("-H", "Authorization: Bearer abc.def.ghi", "$Base/api/finance/accounts")
Invoke-Case "TC07 - Authorization khong co Bearer" 401 @("-H", "Authorization: $($alice.access_token)", "$Base/api/finance/accounts")
Invoke-Case "TC08 - Refresh token dung de goi API" 401 @("-H", $refreshHeader, "$Base/api/finance/accounts")
Invoke-Case "TC09 - Token hop le goi profile" 200 @("-H", $aliceHeader, "$Base/api/profile")

Write-Host "`nTC10: doi 36 giay de access token 30 giay het han..." -ForegroundColor Magenta
Start-Sleep -Seconds 36
Invoke-Case "TC10 - Access token het han" 401 @("-H", $aliceHeader, "$Base/api/finance/accounts")

Write-Host "`n============================================================" -ForegroundColor DarkGray
Write-Host "KET QUA: PASS=$($script:Passed) FAIL=$($script:Failed)" -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Red" })
Write-Host "============================================================" -ForegroundColor DarkGray

if ($script:Failed -gt 0) { exit 1 }
