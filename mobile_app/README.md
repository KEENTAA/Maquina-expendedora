# Grog Mobile App

## Configuración de URLs (centralizada)

Archivo: `lib/src/core/config/app_config.dart`

Variables soportadas con `--dart-define`:
- `API_URL`
- `AUTH_URL`
- `ORCHESTRATOR_URL`
- `SIMUPAY_URL`
- `VENDING_URL`
- `IOT_URL`

## Ejemplos de ejecución

### Emulador Android (localhost del host)
```bash
flutter run --dart-define=API_URL=http://10.0.2.2
```

### Celular real en red local
```bash
flutter run --dart-define=API_URL=http://192.168.1.20
```

### Celular real por hotspot/Wi-Fi (automático)
Desde `grog-platform\mobile_app`:
```powershell
.\run-hotspot.ps1
```
Alias disponible:
```powershell
.\run-hostop.ps1
```
Este script detecta tu IP local activa y ejecuta `flutter run` con:
- `API_URL`
- `AUTH_URL`
- `ORCHESTRATOR_URL`
- `SIMUPAY_URL`
- `VENDING_URL`
- `IOT_URL`

Además limpia `android\local.properties` cuando encuentra `flutter.dart-defines` inválidos (por ejemplo, valores sin formato `KEY=VALUE`) para evitar el error de Gradle `Index 1 out of bounds for length 1`.

## Dashboards conectados

- CLIENT: saldo, transferencias, historial, compra por QR y modo testing.
- ADMIN: máquinas propias, inventario/ventas.
- DEVOPS: estado global de máquinas, telemetría y comandos remotos.

Todos consumen APIs reales del backend.
