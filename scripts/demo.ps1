$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Push-Location $ProjectRoot
try {
  Write-Host "[1/5] Build va khoi dong stack..." -ForegroundColor Cyan
  & docker compose up --build -d --wait
  if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

  Write-Host "`n[2/5] Trang thai container..." -ForegroundColor Cyan
  & docker compose ps
  if ($LASTEXITCODE -ne 0) { throw "docker compose ps failed" }

  Write-Host "`n[3/5] Kiem tra network va trust boundary..." -ForegroundColor Cyan
  & powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\network-test.ps1"
  if ($LASTEXITCODE -ne 0) { throw "network tests failed" }

  Write-Host "`n[4/5] Kiem tra 10 tinh huong JWT..." -ForegroundColor Cyan
  & powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\test.ps1"
  if ($LASTEXITCODE -ne 0) { throw "JWT tests failed" }

  Write-Host "`n[5/5] Kiem tra refresh rotation va logout..." -ForegroundColor Cyan
  & powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\session-test.ps1"
  if ($LASTEXITCODE -ne 0) { throw "session tests failed" }

  Write-Host "`nDEMO HOAN TAT: tat ca kiem tra deu PASS." -ForegroundColor Green
} finally {
  Pop-Location
}
