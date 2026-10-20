"""
RASPBERRY PI PICO WH - SENSORES (NFC + ULTRASONIDO + TEMPERATURA)
-----------------------------------------------------------------
Tercer microcontrolador del sistema GROG Vending.

RESPONSABILIDADES:
  - Emular etiqueta NDEF Tipo 4 para abrir directamente la app móvil (grog_mobile) sin token
  - Compatible con cualquier smartphone (Samsung, Xiaomi, Pixel, Motorola, iPhone)
  - Leer tarjetas/llaveros NFC físicos (Mifare / NTAG) por UART HSU
  - Medir distancia con sensor ultrasónico HC-SR04 (Verificación Two-Phase Commit en tolva)
  - Leer temperatura interna con sensor DHT11
  - Reportar eventos y responder comandos al ESP32 Maestro por UART1
"""

# ═══════════════════════════════════════════════════
# ── FLAGS DE PRUEBA Y DIAGNÓSTICO (CONFIGURACIÓN) ──
# ═══════════════════════════════════════════════════
TEST_COMM_UART_ENABLED = True   # True: activa logs locales en Raspberry Pi / Thonny
ENABLE_TEMP_READING    = True   # True: lee y envía temperatura DHT11 al Maestro
ENABLE_NFC             = True   # True: activa lector/emulador NFC PN532
ENABLE_NFC_LOGS        = True   # True: muestra logs detallados de NFC/App en Thonny
# ═══════════════════════════════════════════════════

from machine import Pin, UART
import utime
import dht

# ─────────────────────────────────────────────
# UART1: comunicación con ESP32 Maestro
# ─────────────────────────────────────────────
uart = UART(1, baudrate=9600, tx=Pin(4), rx=Pin(5))

# ─────────────────────────────────────────────
# DHT11 - Sensor de temperatura de tolva
# ─────────────────────────────────────────────
dht_sensor = dht.DHT11(Pin(10))

# ─────────────────────────────────────────────
# HC-SR04 - Sensor ultrasónico de caída (PoS)
# ─────────────────────────────────────────────
TRIG = Pin(8, Pin.OUT)
ECHO = Pin(9, Pin.IN, Pin.PULL_DOWN)
TRIG.value(0)

# ─────────────────────────────────────────────
# PN532 NFC por UART0 (Pico GP0=TX, GP1=RX)
# Modo HSU: Switches del PN532 en (0, 0 / OFF, OFF)
# ─────────────────────────────────────────────
NFC_UART = None

if ENABLE_NFC:
    try:
        NFC_UART = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1), timeout=10)
        if ENABLE_NFC_LOGS:
            print("[HW-NFC] Puerto UART0 inicializado en GP0(TX) y GP1(RX) @ 115200 baud.")
    except Exception as e:
        if ENABLE_NFC_LOGS:
            print(f"[HW-NFC] ❌ Error al inicializar UART0: {e}")

# ─────────────────────────────────────────────
# INTERVALOS DE LECTURA Y SONDEO
# ─────────────────────────────────────────────
TEMP_INTERVAL_MS = 5000   # Reporte ambiental cada 5 segundos
NFC_POLL_MS      = 250    # Ciclo de sondeo NFC cada 250 ms

# Buffer acumulativo global para UART NFC (evita pérdida de bytes entre ACK y respuestas)
_nfc_rx_buf = bytearray()


def medir_distancia() -> float:
    """Mide distancia con HC-SR04 en cm para confirmación Two-Phase Commit."""
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
    except Exception:
        # DHT11 no conectado o sin resistencia pull-up en GP10
        return -99.0


def _nfc_poll_uart():
    """Lee todos los bytes disponibles en UART hacia el búfer acumulativo."""
    global _nfc_rx_buf
    if NFC_UART and NFC_UART.any():
        _nfc_rx_buf.extend(NFC_UART.read(NFC_UART.any()))


def pn532_send_command(cmd: bytes) -> bool:
    """Envía un comando formateado con preámbulo, longitud y checksums por UART."""
    global _nfc_rx_buf
    if NFC_UART is None:
        return False
        
    # Limpiar buffer residual
    _nfc_rx_buf = bytearray()
    while NFC_UART.any():
        NFC_UART.read(NFC_UART.any())

    length = len(cmd)
    lcs = (~length + 1) & 0xFF
    dcs = (~sum(cmd) + 1) & 0xFF
    frame = bytearray([0x00, 0x00, 0xFF, length, lcs]) + bytearray(cmd) + bytearray([dcs, 0x00])
    
    try:
        NFC_UART.write(frame)
        return True
    except Exception:
        return False


def pn532_read_ack(timeout_ms=100) -> bool:
    """Busca y consume exactamente la trama de ACK (6 bytes), conservando los bytes siguientes."""
    global _nfc_rx_buf
    if NFC_UART is None:
        return False
    start = utime.ticks_ms()
    while utime.ticks_diff(utime.ticks_ms(), start) < timeout_ms:
        _nfc_poll_uart()
        ack_idx = _nfc_rx_buf.find(b"\x00\x00\xff\x00\xff\x00")
        if ack_idx != -1:
            # Consumir el ACK y preservar los datos recibidos posteriormente (trama de datos)
            _nfc_rx_buf = _nfc_rx_buf[ack_idx + 6:]
            return True
        utime.sleep_ms(2)
    return False


def pn532_read_data(timeout_ms=150) -> list[int] | None:
    """Lee y extrae una trama de datos del búfer continuo sin pérdidas ni bloqueos."""
    global _nfc_rx_buf
    if NFC_UART is None:
        return None
    start = utime.ticks_ms()
    while utime.ticks_diff(utime.ticks_ms(), start) < timeout_ms:
        _nfc_poll_uart()

        # Si el inicio contiene un ACK residual, removerlo
        if _nfc_rx_buf.startswith(b"\x00\x00\xff\x00\xff\x00"):
            _nfc_rx_buf = _nfc_rx_buf[6:]
            continue

        idx = _nfc_rx_buf.find(b"\x00\x00\xff")
        if idx != -1 and len(_nfc_rx_buf) >= idx + 5:
            # Descartar si coincide con patrón de ACK interno
            if _nfc_rx_buf[idx : idx + 6] == b"\x00\x00\xff\x00\xff\x00":
                _nfc_rx_buf = _nfc_rx_buf[idx + 6:]
                continue

            length = _nfc_rx_buf[idx + 3]
            lcs = _nfc_rx_buf[idx + 4]
            # Validar integridad: (length + lcs) & 0xFF == 0
            if ((length + lcs) & 0xFF) == 0:
                total_len = idx + 5 + length + 2 # preamb(3) + len(1) + lcs(1) + data(length) + dcs(1) + postamb(1)
                if len(_nfc_rx_buf) >= total_len:
                    payload = list(_nfc_rx_buf[idx + 5 : idx + 5 + length])
                    _nfc_rx_buf = _nfc_rx_buf[total_len:]
                    return payload
        utime.sleep_ms(2)
    return None


def pn532_tg_set_data(data: bytes) -> bool:
    """Envía respuesta APDU al smartphone iniciador mediante TgSetData (0x8E)."""
    if not pn532_send_command(bytes([0xD4, 0x8E]) + data):
        return False
    if not pn532_read_ack(timeout_ms=60):
        return False
    resp = pn532_read_data(timeout_ms=60)
    if resp and len(resp) >= 3 and resp[0] == 0xD5 and resp[1] == 0x8F and resp[2] == 0x00:
        return True
    return False


def pn532_tg_get_data(timeout_ms=350) -> list[int] | None:
    """Espera y recibe una petición APDU del smartphone mediante TgGetData (0x86)."""
    if not pn532_send_command(bytes([0xD4, 0x86])):
        return None
    if not pn532_read_ack(timeout_ms=60):
        return None
    resp = pn532_read_data(timeout_ms=timeout_ms)
    if resp and len(resp) >= 3 and resp[0] == 0xD5 and resp[1] == 0x87:
        if resp[2] == 0x00:
            return resp[3:]  # Retorna bytes del APDU
        elif ENABLE_NFC_LOGS:
            if resp[2] == 0x13:
                print("[NFC-APP] ⚠️ Enlace RF liberado por el teléfono (status=0x13). Mantén el celular firme 2-3 seg.")
            else:
                print(f"[NFC-APP] ⚠️ Estado de enlace RF no disponible (status=0x{resp[2]:02X})")
    return None


def pn532_wakeup():
    """Despierta el módulo PN532 por UART y lo inicializa en modo normal."""
    if not ENABLE_NFC or NFC_UART is None:
        return
    try:
        # 1. Reset limpio por software enviando ACK de corte
        NFC_UART.write(b'\x00\x00\xFF\x00\xFF\x00')
        utime.sleep_ms(30)

        # 2. Secuencia oficial de despertar High-Speed UART (Preámbulo 0x55 0x55 + 16 ceros)
        wakeup_bytes = bytearray([0x55, 0x55] + [0x00] * 16)
        NFC_UART.write(wakeup_bytes)
        utime.sleep_ms(40)

        # 3. Limpiar buffer de entrada UART
        while NFC_UART.any():
            NFC_UART.read(NFC_UART.any())

        # 4. SAMConfiguration (Modo normal 0x01, sin timeout)
        pn532_send_command(bytes([0xD4, 0x14, 0x01, 0x00]))
        utime.sleep_ms(20)
        pn532_read_ack(timeout_ms=50)
        pn532_read_data(timeout_ms=50)

        # 5. RFConfiguration: MaxRetries (Item 5) = 1
        pn532_send_command(bytes([0xD4, 0x32, 0x05, 0xFF, 0x01, 0x01]))
        utime.sleep_ms(20)
        pn532_read_ack(timeout_ms=50)
        pn532_read_data(timeout_ms=50)
    except Exception as e:
        if ENABLE_NFC_LOGS:
            print(f"[HW-NFC] Error en configuración inicial PN532: {e}")


def pn532_check_connection() -> bool:
    """Verifica si el PN532 responde por UART con GetFirmwareVersion (0xD4 0x02)."""
    if not ENABLE_NFC or NFC_UART is None:
        return False
    
    pn532_send_command(bytes([0xD4, 0x02]))
    if not pn532_read_ack(timeout_ms=100):
        pn532_wakeup()
        pn532_send_command(bytes([0xD4, 0x02]))
        if not pn532_read_ack(timeout_ms=100):
            print("[HW-NFC] ❌ PN532 no responde ACK. Revisa:")
            print("          1. ¿Se cruzaron cables? Pico GP0(TX) -> PN532 RXD | Pico GP1(RX) -> PN532 TXD")
            print("          2. ¿DIP switches en placa roja? Deben estar en CH1=0 (OFF), CH2=0 (OFF)")
            print("          3. Desconecta y vuelve a conectar el cable Micro-USB de la Pico para reiniciar alimentación.")
            return False
            
    resp = pn532_read_data(timeout_ms=100)
    if resp and 0xD5 in resp:
        idx = resp.index(0xD5)
        if len(resp) > idx + 4 and resp[idx + 1] == 0x03:
            ic = resp[idx + 2]
            ver = resp[idx + 3]
            rev = resp[idx + 4]
            print(f"[HW-NFC] ✅ PN532 detectado y verificado (IC=0x{ic:02X}, Firmware Ver={ver}.{rev})")
            return True
    print("[HW-NFC] ⚠️ PN532 respondió ACK pero no versión de firmware.")
    return True


def pn532_build_ndef_url_message(url: str) -> bytes:
    """Construye un mensaje NDEF Type 4 estándar con un registro URI (NFC Forum)."""
    url_bytes = url.encode("utf-8")
    # Prefijo 0x00 para URI sin abreviación fija (RFC 3986)
    record_payload = bytes([0x00]) + url_bytes
    
    # NDEF Record Header: MB=1, ME=1, SR=1, TNF=0x01 (Well-Known), Type='U' (0x55)
    ndef_record = bytes([0xD1, 0x01, len(record_payload), 0x55]) + record_payload
    
    # NDEF File: 2 bytes de longitud (NLEN) + payload NDEF
    nlen = len(ndef_record)
    return bytes([(nlen >> 8) & 0xFF, nlen & 0xFF]) + ndef_record


def pn532_reset_rf():
    """Cancela limpiamente cualquier transacción RF previa y devuelve el PN532 a IDLE."""
    global _nfc_rx_buf
    if not ENABLE_NFC or NFC_UART is None:
        return
    try:
        # 1. Enviar ACK de corte por si había un comando activo
        NFC_UART.write(b'\x00\x00\xFF\x00\xFF\x00')
        utime.sleep_ms(15)
        _nfc_rx_buf = bytearray()
        while NFC_UART.any():
            NFC_UART.read(NFC_UART.any())

        # 2. SAMConfiguration para cancelar modo Target y resetear el CIU
        pn532_send_command(bytes([0xD4, 0x14, 0x01, 0x00]))
        utime.sleep_ms(15)
        pn532_read_ack(timeout_ms=40)
        pn532_read_data(timeout_ms=40)
    except Exception:
        pass


def pn532_abort_command():
    """Cancela cualquier comando atascado en el PN532 y restablece la interfaz."""
    pn532_reset_rf()


def pn532_process_ndef_emulation(machine_id: str = "MACHINE-001") -> bool:
    """
    Emula una etiqueta NFC NDEF Type 4 ante el smartphone.
    Entrega el enlace directo grog://vending/<machine_id> para abrir instantáneamente la app.
    Compatible universalmente con Android (Samsung, Xiaomi, Pixel, Motorola) e iOS.
    """
    if not ENABLE_NFC or NFC_UART is None:
        return False

    url = f"grog://vending/{machine_id}"
    ndef_file = pn532_build_ndef_url_message(url)

    # Capability Container (CC) File (15 bytes estándar Type 4 - NXP AN133910)
    cc_file = bytes([
        0x00, 0x0F,       # CCLEN = 15 bytes
        0x20,             # Versión 2.0
        0x00, 0x7F,       # MLe (Max R-APDU size = 127 bytes)
        0x00, 0xFF,       # MLc (Max C-APDU size = 255 bytes)
        0x04, 0x06,       # T & L del NDEF Control TLV
        0xE1, 0x04,       # File ID del NDEF
        0x01, 0x00,       # Max NDEF size (256 bytes)
        0x00,             # Read access: Concedido sin autenticación
        0x00              # Write access: Concedido sin autenticación
    ])

    felica_params = bytearray([
        0x01, 0xFE, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
        0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7,
        0xFF, 0xFF
    ])
    nfcid3t = bytearray([
        0xAA, 0x99, 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11
    ])

    # Comando TgInitAsTarget: Mode 0x05 (Passive only + PICC only)
    # Obliga al smartphone a tratar al PN532 exclusivamente como una tarjeta NDEF Type 4
    init_cmd = bytearray([
        0xD4, 0x8C, 0x05,        # Modo 0x05 (PICC only, Passive only)
        0x04, 0x00,             # SENS_RES
        0x12, 0x34, 0x56,       # NFCID1t (3 bytes UID)
        0x20                    # SEL_RES = 0x20 (ISO/IEC 14443-4 Type 4 Tag)
    ]) + felica_params + nfcid3t + bytearray([0x00, 0x00])

    if not pn532_send_command(bytes(init_cmd)):
        return False
    if not pn532_read_ack(timeout_ms=50):
        pn532_reset_rf()
        return False

    # Ventana de escucha para detectar presencia del smartphone
    init_resp = pn532_read_data(timeout_ms=350)
    if not init_resp:
        pn532_reset_rf()
        return False

    try:
        idx = init_resp.index(0xD5)
        if init_resp[idx + 1] != 0x8D:
            pn532_reset_rf()
            return False
    except (ValueError, IndexError):
        pn532_reset_rf()
        return False

    # Extraer comando si el iniciador ya lo envió en el handshake de activación
    pending_apdu = init_resp[idx + 3:] if len(init_resp) > idx + 3 else None

    if ENABLE_NFC_LOGS:
        if pending_apdu:
            print(f"[NFC-APP] ⚡ ¡Señal RF detectada! Comando inicial recibido ({len(pending_apdu)} bytes)...")
        else:
            print("[NFC-APP] ⚡ ¡Señal RF detectada! Teléfono comunicando con PN532...")

    # El celular estableció enlace RF: intercambiar APDUs (ISO 7816-4)
    selected_file = None
    trans_start = utime.ticks_ms()
    app_delivered = False

    while utime.ticks_diff(utime.ticks_ms(), trans_start) < 2500:
        if pending_apdu is not None:
            apdu = pending_apdu
            pending_apdu = None
        else:
            apdu = pn532_tg_get_data(timeout_ms=350)

        if not apdu or len(apdu) < 4:
            break

        cla, ins, p1, p2 = apdu[0], apdu[1], apdu[2], apdu[3]

        if ENABLE_NFC_LOGS:
            apdu_hex = " ".join([f"{b:02X}" for b in apdu])
            print(f"[NFC-APP] 📲 APDU recibido: {apdu_hex}")

        # ── 1. SELECT (INS = 0xA4) ──
        if ins == 0xA4:
            # Subcaso 1.1: SELECT BY NAME (P1 = 0x04)
            if p1 == 0x04:
                # Comprobar si solicita Aplicación NDEF (AID: D2 76 00 00 85 01 01 o 00)
                if (0xD2 in apdu and 
                    len(apdu) >= apdu.index(0xD2) + 6 and 
                    apdu[apdu.index(0xD2) : apdu.index(0xD2) + 6] == [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01]):
                    selected_file = "NDEF_APP"
                    if ENABLE_NFC_LOGS:
                        print("[NFC-APP] 📂 Negociando Aplicación NDEF Type 4...")
                    pn532_tg_set_data(bytes([0x90, 0x00]))
                else:
                    # Sonda de billetera móvil o pago (Google Wallet, Apple Pay: 2PAY.SYS.DDF01)
                    if ENABLE_NFC_LOGS:
                        print("[NFC-APP] 💳 Sonda de billetera detectada -> Respondiendo 6A 82 (Descartar pago)")
                    pn532_tg_set_data(bytes([0x6A, 0x82]))

            # Subcaso 1.2: SELECT BY ID (P1 = 0x00)
            elif p1 == 0x00:
                if 0xE1 in apdu and apdu.index(0xE1) + 1 < len(apdu) and apdu[apdu.index(0xE1) + 1] == 0x03:
                    selected_file = "CC"
                    if ENABLE_NFC_LOGS:
                        print("[NFC-APP] 📋 Archivo CC seleccionado (Capability Container)")
                    pn532_tg_set_data(bytes([0x90, 0x00]))
                elif 0xE1 in apdu and apdu.index(0xE1) + 1 < len(apdu) and apdu[apdu.index(0xE1) + 1] == 0x04:
                    selected_file = "NDEF"
                    if ENABLE_NFC_LOGS:
                        print("[NFC-APP] 📄 Archivo NDEF seleccionado")
                    pn532_tg_set_data(bytes([0x90, 0x00]))
                else:
                    pn532_tg_set_data(bytes([0x90, 0x00]))
            else:
                pn532_tg_set_data(bytes([0x90, 0x00]))

        # ── 2. READ BINARY (INS = 0xB0) ──
        elif ins == 0xB0:
            offset = (p1 << 8) | p2
            raw_len = apdu[4] if len(apdu) > 4 else 0
            # En ISO 7816-4, Le = 0x00 significa 256 bytes (todo el archivo disponible)
            length = 256 if raw_len == 0 else raw_len

            if selected_file == "CC":
                chunk = cc_file[offset : offset + length]
                if ENABLE_NFC_LOGS:
                    print(f"[NFC-APP] 📤 Enviando CC offset={offset} ({len(chunk)} bytes)...")
                pn532_tg_set_data(chunk + bytes([0x90, 0x00]))

            elif selected_file == "NDEF":
                chunk = ndef_file[offset : offset + length]
                if ENABLE_NFC_LOGS:
                    print(f"[NFC-APP] 📤 Enviando NDEF offset={offset} len={len(chunk)} (de {len(ndef_file)} bytes)...")
                pn532_tg_set_data(chunk + bytes([0x90, 0x00]))

                # Si se completó el envío del archivo NDEF
                if offset + len(chunk) >= len(ndef_file):
                    app_delivered = True
                    if ENABLE_NFC_LOGS:
                        print(f"[NFC-APP] 🚀 ¡Enlace entregado al teléfono!: {url}")
            else:
                pn532_tg_set_data(bytes([0x6A, 0x82]))

        else:
            # Comando APDU no soportado -> 6D 00
            pn532_tg_set_data(bytes([0x6D, 0x00]))

    if app_delivered:
        if ENABLE_NFC_LOGS:
            print("[NFC-APP] ⏳ Esperando confirmación de lectura del smartphone...")
        wait_start = utime.ticks_ms()
        while utime.ticks_diff(utime.ticks_ms(), wait_start) < 700:
            extra = pn532_tg_get_data(timeout_ms=150)
            if not extra:
                break
            pn532_tg_set_data(bytes([0x90, 0x00]))

    # Reset total del CIU para dejar el PN532 completamente limpio y listo para el siguiente celular
    pn532_reset_rf()
    return app_delivered


def pn532_read_passive_card() -> str | None:
    """Lee tarjetas físicas/llaveros solo bajo demanda explícita del ESP32 Maestro."""
    if not ENABLE_NFC or NFC_UART is None:
        return None
    pn532_abort_command()
    if not pn532_send_command(bytes([0xD4, 0x4A, 0x01, 0x00])):
        return None
    if not pn532_read_ack(timeout_ms=50):
        pn532_abort_command()
        return None
    resp = pn532_read_data(timeout_ms=60)
    pn532_abort_command()
    if not resp:
        return None

    try:
        idx = resp.index(0xD5)
        if resp[idx + 1] == 0x4B and resp[idx + 2] >= 1:
            uid_len = resp[idx + 7]
            uid_bytes = resp[idx + 8 : idx + 8 + uid_len]
            return "".join(f"{b:02X}" for b in uid_bytes)
    except (ValueError, IndexError):
        pass
    return None


# ─────────────────────────────────────────────
# BUCLE PRINCIPAL MULTITAREA
# ─────────────────────────────────────────────
def main():
    print("=" * 60)
    print("  GROG VENDING - PICO WH SENSORES (UNIVERSAL)")
    print("=" * 60)
    print(f"  * Logs UART/Consola : {'ACTIVADO' if TEST_COMM_UART_ENABLED else 'DESACTIVADO'}")
    print(f"  * Lectura Temp DHT11: {'ACTIVADO' if ENABLE_TEMP_READING else 'DESACTIVADO'}")
    print(f"  * Emulación App NFC : {'ACTIVADO' if ENABLE_NFC else 'DESACTIVADO'}")
    print("=" * 60)

    # 1. Autocomprobación inicial del hardware NFC PN532
    if ENABLE_NFC:
        pn532_wakeup()
        pn532_check_connection()

    last_temp = utime.ticks_ms()
    last_nfc  = utime.ticks_ms()
    last_hb   = utime.ticks_ms()
    uart_buf  = b""

    while True:
        now = utime.ticks_ms()

        # ── Heartbeat periódico en consola (cada 12 segundos) ──
        if TEST_COMM_UART_ENABLED and utime.ticks_diff(now, last_hb) >= 12000:
            last_hb = now
            print("[HEARTBEAT] 🟢 Pico WH activa | NFC a la espera de celular | ESP32 conectado.")

        # 1. Escuchar peticiones del ESP32 Maestro (Prioridad alta)
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

                if "PING" in cmd:
                    uart.write(b"PONG\n")
                    if TEST_COMM_UART_ENABLED:
                        print("[ESP32-COMM] 📩 'PING' recibido -> Respondido 'PONG' al Maestro.")
                elif "MEDIR" in cmd:
                    # Medición para protocolo Proof of Service (Two-Phase Commit)
                    d = medir_distancia()
                    if d > 0:
                        uart.write(f"DIST:{d}\n".encode())
                        if TEST_COMM_UART_ENABLED:
                            print(f"[PO-SERVICE] 📏 'MEDIR' recibido -> Tolva HC-SR04: {d} cm (Enviado al Maestro)")
                    else:
                        uart.write(b"DIST:-1.0\n")
                        if TEST_COMM_UART_ENABLED:
                            print("[PO-SERVICE] ⚠️ 'MEDIR' recibido -> Sin lectura / Timeout (-1.0 cm)")
                elif "SCAN" in cmd:
                    uid = pn532_read_passive_card()
                    if uid:
                        uart.write(f"NFC:{uid}\n".encode())
                        if ENABLE_NFC_LOGS:
                            print(f"[ESP32-COMM] 📤 Orden 'SCAN' -> Enviado UID al Maestro: {uid}")

        # 2. Lectura y reporte de temperatura periódico (DHT11)
        if ENABLE_TEMP_READING:
            if utime.ticks_diff(now, last_temp) >= TEMP_INTERVAL_MS:
                last_temp = now
                t = leer_temperatura()
                if t != -99.0:
                    uart.write(f"TEMP:{t}\n".encode())
                    if TEST_COMM_UART_ENABLED:
                        print(f"[DHT11] 🌡️ Telemetría ambiental: {t}°C (Enviada a Maestro)")

        # 3. Sondeo continuo de NFC para apertura de la App Móvil
        if ENABLE_NFC and utime.ticks_diff(now, last_nfc) >= NFC_POLL_MS:
            last_nfc = now
            if pn532_process_ndef_emulation():
                if ENABLE_NFC_LOGS:
                    print("[NFC-APP] ✅ App móvil activada en el smartphone del usuario.")
                # Cooldown de 2.0s para permitir retirar el teléfono y dejar limpio el campo RF
                cooldown_start = utime.ticks_ms()
                while utime.ticks_diff(utime.ticks_ms(), cooldown_start) < 2000:
                    if uart.any():
                        # Mantener atención a comandos urgentes del ESP32 durante la pausa
                        break
                    utime.sleep_ms(50)
                last_nfc = utime.ticks_ms()

        utime.sleep_ms(10)


if __name__ == "__main__":
    main()
