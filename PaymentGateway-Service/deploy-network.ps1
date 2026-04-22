Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LocalIPv4 {
    $withGateway = Get-NetIPConfiguration |
        Where-Object { $_.IPv4Address -and $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" } |
        Select-Object -First 1

    if ($withGateway -and $withGateway.IPv4Address) {
        return $withGateway.IPv4Address.IPAddress
    }

    $fallback = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -notlike "169.254.*" } |
        Select-Object -First 1

    if ($fallback) {
        return $fallback.IPAddress
    }

    return "localhost"
}

function Stop-ListeningProcess {
    param([int]$Port)

    $conn = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn) {
        Stop-Process -Id $conn.OwningProcess
    }
}

$servicePath = $PSScriptRoot
$apiPath = Join-Path $servicePath "api"
$frontendPath = Join-Path $servicePath "frontend"

if (-not (Test-Path $apiPath)) { throw "No se encontró la carpeta api en $apiPath" }
if (-not (Test-Path $frontendPath)) { throw "No se encontró la carpeta frontend en $frontendPath" }

Stop-ListeningProcess -Port 8001
Stop-ListeningProcess -Port 5174

$backend = Start-Process -FilePath "python" `
    -ArgumentList "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001" `
    -WorkingDirectory $apiPath `
    -PassThru

$frontend = Start-Process -FilePath "npm.cmd" `
    -ArgumentList "run", "dev" `
    -WorkingDirectory $frontendPath `
    -PassThru

Start-Sleep -Seconds 2
$ip = Get-LocalIPv4

Write-Host ""
Write-Host "SimuPay desplegado en red local" -ForegroundColor Green
Write-Host "Frontend: http://$ip`:5174"
Write-Host "API:      http://$ip`:8001"
Write-Host "PID API:  $($backend.Id)"
Write-Host "PID WEB:  $($frontend.Id)"
Write-Host ""
