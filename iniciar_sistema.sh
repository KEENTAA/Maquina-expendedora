#!/usr/bin/env bash

# Script maestro para levantar el ecosistema GROG:
# 1. Microservicios Docker Backend
# 2. API Gateway Reverso unificado
# 3. Túneles Ngrok para Internet

BASE_DIR="/home/ar/Escritorio/Maquina-expendedora"
BACKEND_DIR="$BASE_DIR/backend"
PROXY_DIR="$BASE_DIR/gateway-proxy"
LOGS_DIR="$BASE_DIR/logs"
NGROK_BIN="/home/ar/.local/bin/ngrok"

mkdir -p "$LOGS_DIR"

echo "=========================================================="
echo "      LEVANTANDO ECOSISTEMA GROG SMART VENDING           "
echo "=========================================================="

# 1. Detener procesos huérfanos previos
echo "[1/4] Limpiando procesos previos..."
pkill -f "gateway.py" 2>/dev/null
pkill -f "ngrok" 2>/dev/null
pkill -f "cloudflared" 2>/dev/null
sleep 1

# 2. Levantar Docker Compose
echo "[2/4] Iniciando contenedores Docker..."
cd "$BACKEND_DIR" || exit 1
docker compose up -d

# 3. Levantar API Gateway Proxy en puerto 8090
echo "[3/4] Iniciando API Gateway Proxy Multihilo (puerto 8090)..."
nohup python3 "$PROXY_DIR/gateway.py" > "$LOGS_DIR/gateway.log" 2>&1 < /dev/null &
sleep 1

# 4. Levantar Túnel Permanente de ngrok
echo "[4/4] Levantando Túnel Permanente Ngrok..."
nohup "$NGROK_BIN" http 8090 --url=passivism-sighing-condense.ngrok-free.dev > "$LOGS_DIR/ngrok.log" 2>&1 < /dev/null &
sleep 2

echo "=========================================================="
echo "          SERVICIOS LISTOS CON DOMINIO PERMANENTE         "
echo "=========================================================="
URL_PERMANENTE="https://passivism-sighing-condense.ngrok-free.dev"

echo "📱 PARA LA APP MÓVIL Y CLIENTES (DOMINIO FIJO):"
echo "   -> $URL_PERMANENTE"
echo "🌐 PARA SIMUPAY WEB (BILLETERA):"
echo "   -> $URL_PERMANENTE/login"
echo "🎮 PARA EL GEMELO DIGITAL 3D (NAVEGADOR WEB):"
echo "   -> $URL_PERMANENTE/unity/"
echo "=========================================================="
