# ==========================================================
#      DETENER ECOSISTEMA GROG SMART VENDING (WINDOWS)
# ==========================================================

$ErrorActionPreference = "Continue"

$BaseDir = $PSScriptRoot
$BackendDir = Join-Path $BaseDir "backend"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      DETENIENDO ECOSISTEMA GROG SMART VENDING           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Detener API Gateway Proxy (puerto 8090)
Write-Host "[1/2] Deteniendo API Gateway Proxy..." -ForegroundColor Yellow
$gatewayConns = Get-NetTCPConnection -State Listen -LocalPort 8090 -ErrorAction SilentlyContinue
if ($gatewayConns) {
    foreach ($conn in $gatewayConns) {
        Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    Write-Host "API Gateway detenido." -ForegroundColor Green
} else {
    Write-Host "API Gateway no estaba en ejecución." -ForegroundColor Gray
}

# 2. Detener contenedores Docker
Write-Host "[2/2] Deteniendo contenedores Docker..." -ForegroundColor Yellow
Push-Location $BackendDir
docker compose stop
Pop-Location

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "           ECOSISTEMA GROG DETENIDO CON ÉXITO            " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
