$ErrorActionPreference = "Stop"
$KC = if ($env:KEYCLOAK_URL) { $env:KEYCLOAK_URL } else { "http://localhost:8080" }
$TokenEndpoint = "$KC/realms/finance-lab/protocol/openid-connect/token"
$LogoutEndpoint = "$KC/realms/finance-lab/protocol/openid-connect/logout"
$script:Passed = 0
$script:Failed = 0

function Invoke-Form([string]$uri, [string[]]$fields) {
  $bodyFile = [System.IO.Path]::GetTempFileName()
  try {
    $curlArgs = @("-sS", "-o", $bodyFile, "-w", "%{http_code}", "-X", "POST", $uri)
    foreach ($field in $fields) {
      $curlArgs += @("--data-urlencode", $field)
    }
    $status = & curl.exe @curlArgs
    $body = Get-Content -Raw -Path $bodyFile
    [PSCustomObject]@{ Status = [int]$status; Body = $body }
  } finally {
    Remove-Item -LiteralPath $bodyFile -Force
  }
}

function Assert-Case([string]$name, [int]$expected, $response) {
  Write-Host "`n$name | expected=$expected actual=$($response.Status)" -ForegroundColor Cyan
  if ($response.Status -eq 200) {
    Write-Host '{"token_response":"received","tokens":"redacted"}'
  } elseif ($response.Body) {
    Write-Host $response.Body
  }
  if ($response.Status -eq $expected) {
    $script:Passed++
    Write-Host "PASS" -ForegroundColor Green
  } else {
    $script:Failed++
    Write-Host "FAIL" -ForegroundColor Red
  }
}

function New-AliceSession {
  $response = Invoke-Form $TokenEndpoint @(
    "grant_type=password",
    "client_id=lab-client",
    "username=alice",
    "password=Alice@123"
  )
  if ($response.Status -ne 200) {
    throw "Cannot create Alice session: HTTP $($response.Status) $($response.Body)"
  }
  $response.Body | ConvertFrom-Json
}

Write-Host "Demo refresh-token rotation..." -ForegroundColor Green
$session = New-AliceSession
$oldRefresh = $session.refresh_token
$rotated = Invoke-Form $TokenEndpoint @(
  "grant_type=refresh_token",
  "client_id=lab-client",
  "refresh_token=$oldRefresh"
)
Assert-Case "SR01 - Refresh token cap token moi" 200 $rotated

$reused = Invoke-Form $TokenEndpoint @(
  "grant_type=refresh_token",
  "client_id=lab-client",
  "refresh_token=$oldRefresh"
)
Assert-Case "SR02 - Refresh token cu khong duoc tai su dung" 400 $reused

Write-Host "`nDemo thu hoi phien bang OIDC logout..." -ForegroundColor Green
$logoutSession = New-AliceSession
$logoutRefresh = $logoutSession.refresh_token
$logout = Invoke-Form $LogoutEndpoint @(
  "client_id=lab-client",
  "refresh_token=$logoutRefresh"
)
Assert-Case "SR03 - Thu hoi phien" 204 $logout

$afterLogout = Invoke-Form $TokenEndpoint @(
  "grant_type=refresh_token",
  "client_id=lab-client",
  "refresh_token=$logoutRefresh"
)
Assert-Case "SR04 - Refresh token bi tu choi sau logout" 400 $afterLogout

Write-Host "`nKET QUA SESSION: PASS=$($script:Passed) FAIL=$($script:Failed)" -ForegroundColor $(if ($script:Failed -eq 0) { "Green" } else { "Red" })
if ($script:Failed -gt 0) { exit 1 }
