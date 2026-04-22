# Grog Platform Backend

## Levantar todo con un solo comando

Desde `grog-platform\backend`:

```powershell
docker compose up -d --build
```

Esto levanta:
- SimuPay base existente (`PaymentGateway-Service`) (8001)
- PostgreSQL (5432)
- Mosquitto MQTT (1883)
- Auth Service (8030)
- SimuPay Integration Service (8020)
- Transaction Orchestrator (8010)
- Vending Service (8040)
- IoT Bridge Service (8050)

## Integración con SimuPay existente

El servicio `simupay-integration-service` consume la pasarela existente por `PAYMENT_GATEWAY_URL`.
En Docker se usa `http://paymentgateway:8001`.

## Configuración centralizada de URLs y puertos

Archivo obligatorio: `backend\.env`

Variables:
- `AUTH_SERVICE_URL`
- `SIMUPAY_SERVICE_URL`
- `ORCHESTRATOR_URL`
- `VENDING_SERVICE_URL`
- `IOT_SERVICE_URL`
- `DATABASE_URL`
- `MQTT_BROKER_URL`

Además:
- `PAYMENT_GATEWAY_URL`
- `PAYMENT_GATEWAY_API_KEY`
- `MERCHANT_PAYOUT_EMAIL`
- `SIMUPAY_INTEGRATION_URL`
- `WEBHOOK_SECRET`
- `JWT_SECRET`
- `IOT_WEBHOOK_ENABLED` (true/false)
- `IOT_WEBHOOK_URL_TEMPLATE` (ej: `http://192.168.1.50:8081/payment-confirmed?tx_id={tx_id}`)
- `IOT_WEBHOOK_TIMEOUT`

Para cambiar URLs: editar `backend\.env` y reiniciar con `docker compose up -d --build`.

## Conexión desde emulador o celular real

1. Encontrar IP local en Windows:
   ```powershell
   ipconfig
   ```
   Usa la IPv4 de tu adaptador Wi-Fi (ej. `192.168.1.20`).

2. En emulador Android usa `10.0.2.2`.
3. En celular real usa `http://192.168.x.x`.

Los servicios deben escuchar en `0.0.0.0` (ya configurado en Docker).
