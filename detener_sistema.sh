#!/usr/bin/env bash

# Script para detener el ecosistema GROG Smart Vending

BASE_DIR="/home/ar/Escritorio/Maquina-expendedora"
BACKEND_DIR="$BASE_DIR/backend"

echo "=========================================================="
echo "      DETENIENDO ECOSISTEMA GROG SMART VENDING           "
echo "=========================================================="

echo "[1/3] Deteniendo API Gateway y Túneles..."
pkill -f "gateway.py" 2>/dev/null
pkill -f "ngrok" 2>/dev/null
pkill -f "cloudflared" 2>/dev/null

echo "[2/3] Deteniendo contenedores Docker..."
cd "$BACKEND_DIR" || exit 1
docker compose stop

echo "[3/3] Sistema apagado correctamente."
echo "=========================================================="
