#!/usr/bin/env bash
# Script para compilar el Gemelo Digital GROG en WebGL
set -e

PROJECT_DIR="/home/ar/Proyectos/GemeloVending"
UNITY_BIN="/home/ar/Unity/Hub/Editor/6000.6.2f1/Editor/Unity"
LOG_FILE="$PROJECT_DIR/build_webgl.log"
BACKEND_DIST="/home/ar/Escritorio/Maquina-expendedora/backend/unity-webgl/dist"

echo "=========================================================="
echo "      COMPILACIÓN DE GROG GEMELO DIGITAL A WEBGL         "
echo "=========================================================="
echo "Versión de Unity: 6000.6.2f1 (Unity 6)"
echo "Proyecto: $PROJECT_DIR"
echo "Destino Docker: $BACKEND_DIST"
echo "Log de compilación: $LOG_FILE"
echo "=========================================================="
echo "Iniciando compilador IL2CPP/WebGL en segundo plano..."

"$UNITY_BIN" -batchmode -quit \
  -projectPath "$PROJECT_DIR" \
  -executeMethod WebGLDeployBuilder.BuildWebGL \
  -logFile "$LOG_FILE"

echo ""
echo "=========================================================="
if [ -f "$PROJECT_DIR/Builds/GemeloVending_WebGL.zip" ]; then
    echo "✅ ¡COMPILACIÓN WEBGL COMPLETADA CON ÉXITO!"
    echo "📦 Archivo ZIP para itch.io: $PROJECT_DIR/Builds/GemeloVending_WebGL.zip"
    echo "🌐 Desplegado en Docker: http://localhost:8060"
    echo "🔗 Acceso público: https://passivism-sighing-condense.ngrok-free.dev/unity/"
else
    echo "⚠️ Verifique los detalles en el log: $LOG_FILE"
fi
echo "=========================================================="
