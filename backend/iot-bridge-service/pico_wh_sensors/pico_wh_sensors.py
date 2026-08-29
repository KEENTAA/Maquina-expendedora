"""
RASPBERRY PI PICO WH - SENSORES (NFC + ULTRASONIDO + TEMPERATURA)
-----------------------------------------------------------------
Tercer microcontrolador del sistema GROG Vending.

RESPONSABILIDADES:
  - Leer tarjetas NFC (PN532 por I2C) para autenticación/pago
  - Medir distancia con sensor ultrasónico HC-SR04 (detección de caída de producto)
  - Leer temperatura con sensor DHT11
  - Reportar todo al ESP32 Maestro por UART1
"""

# ═══════════════════════════════════════════════════
# ── FLAGS DE PRUEBA Y DIAGNÓSTICO (CONFIGURACIÓN) ──
# Cambia a True o False según lo que desees activar:
TEST_COMM_UART_ENABLED = False  # False: modo producción (silencioso y optimizado)
ENABLE_TEMP_READING    = True   # True: lee y envía temperatura DHT11 al Maestro
ENABLE_NFC             = True   # True: activa lector NFC PN532 (con protección try/except)
# ═══════════════════════════════════════════════════

from machine import Pin, I2C, UART
import utime
import dht

# ─────────────────────────────────────────────
# UART1: comunicación con ESP32 Maestro
# ─────────────────────────────────────────────
uart = UART(1, baudrate=9600, tx=Pin(4), rx=Pin(5))

# ─────────────────────────────────────────────
# DHT11 - Sensor de temperatura
# ─────────────────────────────────────────────
dht_sensor = dht.DHT11(Pin(10))

# ─────────────────────────────────────────────
# HC-SR04 - Sensor ultrasónico
# ─────────────────────────────────────────────
TRIG = Pin(8, Pin.OUT)
ECHO = Pin(9, Pin.IN, Pin.PULL_DOWN)
TRIG.value(0)

# ─────────────────────────────────────────────
# PN532 NFC por I2C (solo si ENABLE_NFC es True)
# ─────────────────────────────────────────────
I2C_BUS    = None
PN532_ADDR = 0x24  # Dirección I2C estándar del PN532

if ENABLE_NFC:
    try:
        I2C_BUS = I2C(1, sda=Pin(6), scl=Pin(7), freq=100000)
        devices = I2C_BUS.scan()
        print(f"[*] I2C Bus escaneado (GP6/GP7). Dispositivos encontrados: {[hex(d) for d in devices]}")
        if PN532_ADDR in devices:
            print(f"[NFC] Dispositivo PN532 encontrado en dirección {hex(PN532_ADDR)}.")
        else:
            print(f"[NFC] AVISO: No se detectó el PN532 en {hex(PN532_ADDR)}. Revisa switches (I2C) y cables.")
    except Exception as e:
        print(f"[NFC] Error al inicializar o escanear I2C: {e}")

# ─────────────────────────────────────────────
# INTERVALOS DE LECTURA
# ─────────────────────────────────────────────
TEMP_INTERVAL_MS = 5000   # Cada 5 segundos
DIST_INTERVAL_MS = 500    # Cada 500 ms (modo pasivo)
NFC_POLL_MS      = 300    # Cada 300 ms


def medir_distancia() -> float:
    """Mide distancia con HC-SR04 en cm."""
    TRIG.value(0)
    utime.sleep_us(5)
    TRIG.value(1)
    utime.sleep_us(10)
    TRIG.value(0)

    # Esperar flanco de subida
    timeout_start = utime.ticks_us()
    while ECHO.value() == 0:
        if utime.ticks_diff(utime.ticks_us(), timeout_start) > 30000:
            return -1.0

    pulse_start = utime.ticks_us()

    # Esperar flanco de bajada
    while ECHO.value() == 1:
        if utime.ticks_diff(utime.ticks_us(), pulse_start) > 30000:
            return -1.0

    pulse_end = utime.ticks_us()
    duration  = utime.ticks_diff(pulse_end, pulse_start)
    cm        = (duration * 0.0343) / 2.0

    if cm < 1.0 or cm > 400.0:
        return -1.0
    return round(cm, 1)


def leer_temperatura() -> float:
    """Lee temperatura del DHT11 en °C."""
    try:
        dht_sensor.measure()
        return float(dht_sensor.temperature())
    except Exception as e:
        if TEST_COMM_UART_ENABLED:
            print(f"[DHT11] Error lectura: {e}")
        return -99.0


def pn532_send_command(cmd: bytes) -> bool:
    """Envía un comando formateado con preámbulo, longitud y checksums."""
    if I2C_BUS is None:
        print("[I2C] Error: I2C_BUS es None")
        return False
    length = len(cmd)
    lcs = (~length + 1) & 0xFF
    dcs = (~sum(cmd) + 1) & 0xFF
    frame = bytearray([0x00, 0x00, 0xFF, length, lcs]) + bytearray(cmd) + bytearray([dcs, 0x00])
    try:
        I2C_BUS.writeto(PN532_ADDR, frame)
        return True
    except Exception as e:
        print(f"[I2C] Excepción al escribir en PN532: {e}")
        return False


def pn532_wait_ready(timeout_ms=50) -> bool:
    """Espera a que el bit READY (bit 0) del PN532 esté en 1."""
    if I2C_BUS is None:
        return False
    start = utime.ticks_ms()
    while utime.ticks_diff(utime.ticks_ms(), start) < timeout_ms:
        try:
            status = I2C_BUS.readfrom(PN532_ADDR, 1)
            if status and (status[0] & 0x01):
                return True
        except Exception:
            pass
        utime.sleep_ms(2)
    return False


def pn532_read_ack() -> bool:
    """Lee y consume la trama de ACK del PN532."""
    if not pn532_wait_ready(30):
        return False
    try:
        ack = I2C_BUS.readfrom(PN532_ADDR, 7)
        if len(ack) >= 7 and ack[1:7] == b"\x00\x00\xff\x00\xff\x00":
            return True
    except Exception:
        pass
    return False


def pn532_read_data(max_len=32, timeout_ms=80) -> list[int] | None:
    """Espera y lee la trama de datos de respuesta del PN532."""
    if not pn532_wait_ready(timeout_ms):
        return None
    try:
        raw = I2C_BUS.readfrom(PN532_ADDR, max_len + 1)
        if raw and (raw[0] & 0x01):
            return list(raw[1:])
    except Exception:
        pass
    return None


def pn532_wakeup():
    """Despierta el módulo y configura reintentos rápidos de lectura."""
    if not ENABLE_NFC or NFC_UART is None:
        return
    try:
        # 0. Abortar cualquier comando previo que se haya quedado pegado (Reset por software)
        NFC_UART.write(b'\x00\x00\xFF\x00\xFF\x00')
        utime.sleep_ms(50)
        
        # Enviar dummy bytes para despertar el chip (secuencia de UART)
        wakeup = bytearray([0x55, 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x03, 0xFD, 0xD4, 0x14, 0x01, 0x17, 0x00])
        NFC_UART.write(wakeup)
        utime.sleep_ms(50)
        pn532_read_ack()
        pn532_read_data(16, timeout_ms=50)

        # 2. RFConfiguration: MaxRetries (Item 5) = 1 intento pasivo para polling no bloqueante
        pn532_send_command(bytes([0xD4, 0x32, 0x05, 0xFF, 0x01, 0x01]))
        utime.sleep_ms(20)
        pn532_read_ack()
        pn532_read_data(16, timeout_ms=50)

        print("[NFC] PN532 configurado y listo en modo I2C rápido.")
    except Exception as e:
        print(f"[NFC] Error en configuración inicial PN532: {e}")


def pn532_build_ndef_url_message(url: str) -> bytes:
    """Construye un mensaje NDEF Type 4 estándar con un registro URI."""
    url_bytes = url.encode("utf-8")
    # Prefijo 0x00 para URI sin abreviación fija
    record_payload = bytes([0x00]) + url_bytes
    
    # NDEF Record Header: MB=1, ME=1, SR=1, TNF=0x01 (Well-Known), Type='U' (0x55)
    ndef_record = bytes([0xD1, 0x01, len(record_payload), 0x55]) + record_payload
    
    # NDEF File: 2 bytes de longitud (NLEN) + payload
    nlen = len(ndef_record)
    return bytes([(nlen >> 8) & 0xFF, nlen & 0xFF]) + ndef_record


def pn532_process_ndef_emulation(machine_id: str = "MACHINE-001") -> str | None:
    """
    Emula una etiqueta NFC NDEF Type 4 ante el teléfono móvil.
    Genera un token de sesión de 30 segundos y lo entrega al celular para abrir la app.
    """
    if not ENABLE_NFC or I2C_BUS is None:
        return None

    # Generar Token único de 30s basado en timestamp
    now_ms = utime.ticks_ms()
    token = f"TOK{now_ms:08X}"
    url = f"grog://vending/{machine_id}?token={token}&exp=30"
    ndef_file = pn532_build_ndef_url_message(url)

    # Capability Container (CC) File (15 bytes estándar Type 4)
    cc_file = bytes([
        0x00, 0x0F,       # CCLEN = 15 bytes
        0x20,             # Versión 2.0
        0x00, 0x3B,       # MLe (Max R-APDU size)
        0x00, 0x34,       # MLc (Max C-APDU size)
        0x04, 0x06,       # T & L del NDEF Control TLV
        0xE1, 0x04,       # File ID del NDEF
        (len(ndef_file) >> 8) & 0xFF, len(ndef_file) & 0xFF, # Max NDEF size
        0x00,             # Read access: No security
        0x00              # Write access: No security
    ])

    # Comando TgInitAsTarget (Modo Pasivo Type A con SEL_RES=0x20 para ISO14443-4)
    init_cmd = bytearray([
        0xD4, 0x8C, 0x05,
        0x04, 0x00,             # SENS_RES (Type A)
        0x12, 0x34, 0x56,       # NFCID1t (3 bytes)
        0x20                    # SEL_RES = 0x20 (ISO/IEC 14443-4)
    ]) + bytearray(18) + bytearray(10) + bytearray([0x00, 0x00])

    if not pn532_send_command(bytes(init_cmd)):
        return None
    if not pn532_read_ack():
        print("[NFC-EMU] ❌ El módulo NFC no responde. Forzando reinicio (WakeUp)...")
        pn532_wakeup()
        return None

    # Esperar si un celular entra al campo RF
    init_resp = pn532_read_data(64, timeout_ms=10000)
    if not init_resp:
        pn532_abort_command()
        return None

    try:
        idx = init_resp.index(0xD5)
        if init_resp[idx + 1] != 0x8D:
            pn532_abort_command()
            return None
    except (ValueError, IndexError):
        pn532_abort_command()
        return None

    # El celular está conectado, responder a las peticiones APDU (ISO 7816-4)
    selected_file = None
    trans_start = utime.ticks_ms()

    while utime.ticks_diff(utime.ticks_ms(), trans_start) < 3000:
        # 1. TgGetData: Recibir APDU del celular
        if not pn532_send_command(bytes([0xD4, 0x86])):
            break
        if not pn532_read_ack():
            break
            
        apdu_resp = pn532_read_data(128, timeout_ms=500)
        if not apdu_resp:
            break

        try:
            apdu_idx = apdu_resp.index(0xD5)
            if apdu_resp[apdu_idx + 1] != 0x87 or apdu_resp[apdu_idx + 2] != 0x00:
                break
            apdu = apdu_resp[apdu_idx + 3 :]
        except (ValueError, IndexError):
            break

        if len(apdu) < 4:
            break

        cla, ins, p1, p2 = apdu[0], apdu[1], apdu[2], apdu[3]

        # ── SELECT FILE / APPLICATION ──
        if ins == 0xA4:
            if len(apdu) >= 7 and apdu[4] == 0x07 and apdu[5:12] == [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]:
                selected_file = "NDEF_APP"
                pn532_send_command(bytes([0xD4, 0x8E, 0x90, 0x00]))
            elif len(apdu) >= 7 and apdu[5:7] == [0xE1, 0x03]:
                selected_file = "CC"
                pn532_send_command(bytes([0xD4, 0x8E, 0x90, 0x00]))
            elif len(apdu) >= 7 and apdu[5:7] == [0xE1, 0x04]:
                selected_file = "NDEF"
                pn532_send_command(bytes([0xD4, 0x8E, 0x90, 0x00]))
            else:
                pn532_send_command(bytes([0xD4, 0x8E, 0x90, 0x00]))
            pn532_read_ack()
            pn532_read_data(32, timeout_ms=80)

        # ── READ BINARY ──
        elif ins == 0xB0:
            offset = (p1 << 8) | p2
            length = apdu[4] if len(apdu) > 4 else 15

            if selected_file == "CC":
                chunk = cc_file[offset : offset + length]
                reply = bytes([0xD4, 0x8E]) + chunk + bytes([0x90, 0x00])
                pn532_send_command(reply)
                pn532_read_ack()
                pn532_read_data(32, timeout_ms=80)
            elif selected_file == "NDEF":
                chunk = ndef_file[offset : offset + length]
                reply = bytes([0xD4, 0x8E]) + chunk + bytes([0x90, 0x00])
                pn532_send_command(reply)
                pn532_read_ack()
                pn532_read_data(32, timeout_ms=80)
                
                # Solo terminamos si el celular ya leyó hasta el final del archivo NDEF
                if offset + length >= len(ndef_file):
                    print(f"[NFC] 📱 Celular conectado! Enlace enviado con Token: {token} (30s)")
                    pn532_abort_command()
                    pn532_wakeup()
                    return token
            else:
                pn532_send_command(bytes([0xD4, 0x8E, 0x6A, 0x82]))
                pn532_read_ack()
                pn532_read_data(32, timeout_ms=80)

    pn532_abort_command()
    return None


def pn532_read_uid() -> str | None:
    """Busca tarjetas NFC Type A físicas y retorna su UID si no hay celular emulando."""
    if not ENABLE_NFC or I2C_BUS is None:
        return None
    
    # 1. Primero intentar emular NDEF con el teléfono
    token = pn532_process_ndef_emulation()
    if token:
        return f"TOKEN:{token}"
    
    # 2. Si no hay teléfono conectado, hacer lectura pasiva de tarjetas/llaveros
    if not pn532_send_command(bytes([0xD4, 0x4A, 0x01, 0x00])):
        return None
    
    pn532_read_ack()
    resp = pn532_read_data(32, timeout_ms=30)
    if not resp:
        return None
    
    try:
        idx = resp.index(0xD5)
        if resp[idx + 1] == 0x4B and resp[idx + 2] > 0:
            uid_len = resp[idx + 7]
            uid_bytes = resp[idx + 8 : idx + 8 + uid_len]
            return "".join(f"{b:02X}" for b in uid_bytes)
    except (ValueError, IndexError):
        pass
    
    return None


def main():
    print("─── PICO WH SENSORES INICIADO ───")
    print(f"[*] Config: Test UART={TEST_COMM_UART_ENABLED} | Temp={ENABLE_TEMP_READING} | NFC={ENABLE_NFC}")
    print("[*] UART1 activo en GP4 (TX) y GP5 (RX) a 9600 baud.")
    pn532_wakeup()

    last_temp = utime.ticks_ms()
    last_dist = utime.ticks_ms()
    last_nfc  = utime.ticks_ms()
    last_hb   = utime.ticks_ms()
    last_uid  = None
    uart_buf  = b""

    while True:
        now = utime.ticks_ms()

        # ── Heartbeat visual periódico en consola de Thonny ──
        if TEST_COMM_UART_ENABLED and utime.ticks_diff(now, last_hb) >= 3000:
            last_hb = now
            print("[HEARTBEAT] Pico WH en bucle activo, esperando datos UART del ESP32...")

        # 1. Escuchar peticiones del ESP32 Maestro
        if uart.any():
            uart_buf += uart.read(uart.any())
            while b"\n" in uart_buf:
                line, uart_buf = uart_buf.split(b"\n", 1)
                try:
                    cmd = line.decode("utf-8", "ignore").strip()
                except Exception:
                    cmd = ""

                if not cmd:
                    continue

                if TEST_COMM_UART_ENABLED:
                    print(f"[TEST-UART] Recibido de ESP32 Maestro: '{cmd}'")

                if "PING" in cmd:
                    uart.write(b"PONG\n")
                    if TEST_COMM_UART_ENABLED:
                        print("[TEST-UART] -> Respondido 'PONG' al Maestro.")
                elif "MEDIR" in cmd:
                    d = medir_distancia()
                    if d > 0:
                        uart.write(f"DIST:{d}\n".encode())
                        if TEST_COMM_UART_ENABLED:
                            print(f"[TEST-UART] -> Enviada medida urgente: {d} cm")
                elif "SCAN" in cmd:
                    uid = pn532_read_uid()
                    if uid:
                        uart.write(f"NFC:{uid}\n".encode())
                        if TEST_COMM_UART_ENABLED:
                            print(f"[TEST-UART] -> Enviado NFC: {uid}")

        # 2. Lectura y reporte de temperatura periódico (si está habilitado)
        if ENABLE_TEMP_READING:
            if utime.ticks_diff(now, last_temp) >= TEMP_INTERVAL_MS:
                last_temp = now
                t = leer_temperatura()
                if t != -99.0:
                    uart.write(f"TEMP:{t}\n".encode())
                    if TEST_COMM_UART_ENABLED:
                        print(f"[TEST-UART] Temperatura enviada: {t}°C")

        # 3. Lectura periódica de distancia
        if utime.ticks_diff(now, last_dist) >= DIST_INTERVAL_MS:
            last_dist = now
            d = medir_distancia()
            if d > 0:
                uart.write(f"DIST:{d}\n".encode())

        # 4. Polling continuo de tarjetas NFC
        if ENABLE_NFC and utime.ticks_diff(now, last_nfc) >= NFC_POLL_MS:
            last_nfc = now
            uid = pn532_read_uid()
            if uid and uid != last_uid:
                last_uid = uid
                uart.write(f"NFC:{uid}\n".encode())
                print(f"[NFC] UID Detectado: {uid}")
            elif not uid:
                last_uid = None

        utime.sleep_ms(10)


if __name__ == "__main__":
    main()
