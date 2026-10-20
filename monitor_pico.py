#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Monitor de Consola y Logs en Tiempo Real - Raspberry Pi Pico WH (NFC / DHT11 / Ultrasonido)
Lee el puerto serie USB (COM) de la Raspberry Pi Pico y muestra los logs del NFC.
"""

import sys
import time
import os

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("Instalando pyserial...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyserial"])
    import serial
    import serial.tools.list_ports

def find_pico_port():
    """Detecta automáticamente el puerto COM de la Raspberry Pi Pico WH (VID 2E8A)."""
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        # VID 0x2E8A es Raspberry Pi (RP2040)
        if p.vid == 0x2E8A or "Pico" in (p.description or "") or "Pico" in (p.manufacturer or ""):
            return p.device, p.description
    
    # Si solo hay un puerto serie USB disponible, sugerirlo
    for p in ports:
        if "USB" in (p.description or ""):
            return p.device, p.description
            
    return None, None

def check_thonny_running():
    """Verifica si Thonny está abierto, ya que Thonny bloquea el puerto COM de la Pico."""
    import subprocess
    try:
        output = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", "Get-Process -Name thonny -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id"],
            text=True
        ).strip()
        return bool(output)
    except Exception:
        return False

def close_thonny():
    """Cierra Thonny para liberar el puerto COM."""
    import subprocess
    try:
        subprocess.run(["taskkill", "/F", "/IM", "thonny.exe"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1)
        return True
    except Exception:
        return False

def main():
    print("=" * 65)
    print("   MONITOR DE CONSOLA SERIAL - RASPBERRY PI PICO WH (NFC)")
    print("=" * 65)

    port, desc = find_pico_port()
    if not port:
        print("❌ No se encontró la Raspberry Pi Pico conectada por USB.")
        print("Puertos COM detectados:")
        for p in serial.tools.list_ports.comports():
            print(f"  • {p.device}: {p.description} (VID: {p.vid:04X if p.vid else 'None'})")
        sys.exit(1)

    print(f"✅ Dispositivo detectado: {port} ({desc})")

    # Verificar si Thonny está bloqueando el puerto
    if check_thonny_running():
        print("\n⚠️ AVISO: Se detectó que Thonny IDE está abierto.")
        print("   Thonny mantiene bloqueado el puerto COM4 en exclusiva.")
        print("   Opciones:")
        print("   1. Puedes ver la consola directamente en la pestaña 'Shell' de Thonny.")
        print("   2. O cierra Thonny para ver los logs aquí en esta consola.")
        print("\n¿Deseas cerrar Thonny automáticamente para ver los logs aquí? (s/n): ", end="", flush=True)
        
        # En modo no interactivo o si se pasa argumento --force-close
        if "--force-close" in sys.argv:
            resp = "s"
            print("s")
        else:
            try:
                resp = input().strip().lower()
            except EOFError:
                resp = "n"

        if resp == "s":
            print("Cerrando Thonny...")
            close_thonny()
            time.sleep(1)
        else:
            print("\n💡 Tip: Abre la ventana de Thonny en tu pantalla y mira la sección inferior 'Shell'.")
            print("   Allí ya están saliendo los logs en vivo.")
            return

    print(f"\n📡 Conectando a {port} a 115200 baud...")
    try:
        ser = serial.Serial(port, 115200, timeout=1)
        print("🟢 Conectado con éxito. Presiona Ctrl + C para salir.")
        print("-" * 65)
        print("Esperando eventos del lector NFC y sensores...")
        print("-" * 65)
    except serial.SerialException as e:
        print(f"❌ Error al abrir {port}: {e}")
        if "PermissionError" in str(e) or "Acceso denegado" in str(e):
            print("El puerto aún está ocupado por otra aplicación (Thonny, Arduino, etc.).")
        sys.exit(1)

    try:
        while True:
            line = ser.readline()
            if line:
                try:
                    text = line.decode("utf-8", errors="replace").strip()
                except Exception:
                    text = str(line)

                if text:
                    now = time.strftime("%H:%M:%S")
                    # Resaltar logs según el tipo
                    if "[NFC-APP]" in text or "NFC" in text:
                        print(f"[{now}] 🏷️  \033[92m{text}\033[0m")  # Verde
                    elif "[HW-NFC]" in text:
                        print(f"[{now}] ⚙️  \033[96m{text}\033[0m")  # Cyan
                    elif "[HEARTBEAT]" in text:
                        print(f"[{now}] 💓 \033[94m{text}\033[0m")  # Azul
                    elif "[ESP32-COMM]" in text:
                        print(f"[{now}] 🔄 \033[93m{text}\033[0m")  # Amarillo
                    elif "[PO-SERVICE]" in text:
                        print(f"[{now}] 📦 \033[95m{text}\033[0m")  # Magenta
                    elif "[DHT11]" in text:
                        print(f"[{now}] 🌡️  \033[97m{text}\033[0m")  # Blanco
                    else:
                        print(f"[{now}] {text}")
    except KeyboardInterrupt:
        print("\n\n⏹ Monitor serial detenido por el usuario.")
    finally:
        ser.close()

if __name__ == "__main__":
    main()
