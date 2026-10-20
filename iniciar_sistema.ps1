# ==========================================================
#      LEVANTAR ECOSISTEMA GROG SMART VENDING (WINDOWS)
# ==========================================================

$ErrorActionPreference = "Continue"

$BaseDir = $PSScriptRoot
$BackendDir = Join-Path $BaseDir "backend"
$ProxyDir = Join-Path $BaseDir "gateway-proxy"
$LogsDir = Join-Path $BaseDir "logs"
$DistDir = Join-Path $BackendDir "unity-webgl\dist"

if (-not (Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
}

if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      LEVANTANDO ECOSISTEMA GROG SMART VENDING           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verificar Docker
Write-Host "[1/4] Verificando Docker Desktop..." -ForegroundColor Yellow
$dockerReady = $false
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerReady = $true }
} catch {}

if (-not $dockerReady) {
    Write-Host "Iniciando Docker Desktop, por favor espere..." -ForegroundColor Gray
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -ErrorAction SilentlyContinue
    $attempts = 0
    while (-not $dockerReady -and $attempts -lt 30) {
        Start-Sleep -Seconds 2
        $attempts++
        try {
            $null = docker info 2>&1
            if ($LASTEXITCODE -eq 0) { $dockerReady = $true }
        } catch {}
    }
}

if (-not $dockerReady) {
    Write-Host "ERROR: No se pudo conectar a Docker. Verifique que Docker Desktop esté encendido." -ForegroundColor Red
    exit 1
}
Write-Host "Docker está listo y operativo." -ForegroundColor Green

# 2. Levantar Docker Compose
Write-Host "[2/4] Iniciando contenedores Docker (Microservicios)..." -ForegroundColor Yellow
Push-Location $BackendDir
docker compose up -d
Pop-Location

# 3. Detener gateway previo si ya corría y arrancar gateway.py
Write-Host "[3/4] Iniciando API Gateway Proxy Multihilo (puerto 8090)..." -ForegroundColor Yellow
$gatewayConns = Get-NetTCPConnection -State Listen -LocalPort 8090 -ErrorAction SilentlyContinue
if ($gatewayConns) {
    foreach ($conn in $gatewayConns) {
        Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}

$gatewayScript = Join-Path $ProxyDir "gateway.py"
$gatewayLog = Join-Path $LogsDir "gateway.log"

Start-Process -FilePath "python" `
    -ArgumentList "`"$gatewayScript`"" `
    -RedirectStandardOutput $gatewayLog `
    -RedirectStandardError $gatewayLog `
    -WindowStyle Hidden

Start-Sleep -Seconds 2

# 4. Obtener IP Local
function Get-LocalIPv4 {
    $withGateway = Get-NetIPConfiguration |
        Where-Object { $_.IPv4Address -and $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" } |
        Select-Object -First 1

    if ($withGateway -and $withGateway.IPv4Address) {
        return $withGateway.IPv4Address.IPAddress
    }
    return "localhost"
}

$localIP = Get-LocalIPv4

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "          ECOSISTEMA GROG INICIADO CORRECTAMENTE          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 API Gateway Unificado:       http://localhost:8090" -ForegroundColor Cyan
Write-Host "💳 SimuPay Web Portal:          http://localhost:5174  o  http://localhost:8090" -ForegroundColor White
Write-Host "🎮 Gemelo Digital WebGL:        http://localhost:8060  o  http://localhost:8090/unity/" -ForegroundColor White
Write-Host ""
Write-Host "📋 Swagger APIs (Documentación Interactiva):" -ForegroundColor Magenta
Write-Host "   • Orquestador:               http://localhost:8010/docs"
Write-Host "   • Vending Service:           http://localhost:8040/docs"
Write-Host "   • Auth Service:              http://localhost:8030/docs"
Write-Host "   • SimuPay Integration:       http://localhost:8020/docs"
Write-Host "   • Payment Gateway API:       http://localhost:8001/docs"
Write-Host "   • IoT Bridge Service:        http://localhost:8050/docs"
Write-Host "   • Notification Service:      http://localhost:8070/docs"
Write-Host "   • Audit Service:             http://localhost:8080/docs"
Write-Host ""
Write-Host "📱 IP para App Móvil Flutter:   http://$localIP`:8090" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
