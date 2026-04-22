Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Repair-AndroidLocalPropertiesDartDefines {
    param(
        [string]$LocalPropertiesPath
    )

    if (-not (Test-Path $LocalPropertiesPath)) {
        return
    }

    $lines = Get-Content -Path $LocalPropertiesPath
    $updated = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $lines[$i].StartsWith("flutter.dart-defines=")) {
            continue
        }

        $encodedDefines = $lines[$i].Substring("flutter.dart-defines=".Length)
        if ([string]::IsNullOrWhiteSpace($encodedDefines)) {
            continue
        }

        $validEncodedDefines = @()
        $invalidCount = 0

        foreach ($encodedDefine in $encodedDefines.Split(",")) {
            try {
                $decodedDefine = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedDefine))
            } catch {
                $invalidCount++
                continue
            }

            if ($decodedDefine.Contains("=")) {
                $validEncodedDefines += $encodedDefine
            } else {
                $invalidCount++
            }
        }

        if ($invalidCount -gt 0) {
            if ($validEncodedDefines.Count -gt 0) {
                $lines[$i] = "flutter.dart-defines=$($validEncodedDefines -join ',')"
            } else {
                $lines[$i] = ""
            }
            $updated = $true
            Write-Host "Se limpiaron dart-defines inválidos en android\\local.properties (sin formato KEY=VALUE)." -ForegroundColor Yellow
        }
    }

    if ($updated) {
        Set-Content -Path $LocalPropertiesPath -Value ($lines | Where-Object { $_ -ne "" })
    }
}

function Get-LocalIPv4 {
    $primary = Get-NetIPConfiguration |
        Where-Object { $_.IPv4Address -and $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" } |
        Select-Object -First 1

    if ($primary -and $primary.IPv4Address) {
        return $primary.IPv4Address.IPAddress
    }

    $fallback = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -notlike "169.254.*" } |
        Select-Object -First 1

    if ($fallback) {
        return $fallback.IPAddress
    }

    throw "No se pudo detectar una IPv4 local activa."
}

$ip = Get-LocalIPv4
Write-Host "Usando IP local: $ip" -ForegroundColor Green

$localPropertiesPath = Join-Path $PSScriptRoot "android\local.properties"
Repair-AndroidLocalPropertiesDartDefines -LocalPropertiesPath $localPropertiesPath

$args = @(
    "run",
    "--dart-define=API_URL=http://$ip",
    "--dart-define=AUTH_URL=http://$ip`:8030",
    "--dart-define=ORCHESTRATOR_URL=http://$ip`:8010",
    "--dart-define=SIMUPAY_URL=http://$ip`:8020",
    "--dart-define=VENDING_URL=http://$ip`:8040",
    "--dart-define=IOT_URL=http://$ip`:8050"
)

flutter @args
