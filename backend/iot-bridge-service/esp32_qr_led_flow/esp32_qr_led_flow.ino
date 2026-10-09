#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <TFT_eSPI.h>
#include "qrcode.h"
#include <Keypad.h>
#include <Preferences.h> // MEMORIA PERMANENTE

// ═══════════════════════════════════════════════════
// ── FLAGS DE PRUEBA Y DIAGNÓSTICO (CONFIGURACIÓN) ──
// Cambia a true o false según lo que desees activar:
const bool TEST_COMM_PICO_ENABLED = false;  // false: modo producción (sin pings continuos de test)
const bool ENABLE_TEMP_READING     = true;   // true: lee y reporta temperatura DHT11 en TFT y telemetría
// ═══════════════════════════════════════════════════

// ═══════════════════════════════════════════════════
// ARQUITECTURA DE MICROPROCESADORES:
//   ESP32 #1 (este) → TFT + Keypad + WiFi + QR (MAESTRO)
//   ESP32 #2        → Motores PAP          (ESCLAVO MOTORES)  Serial2 (RX=16, TX=17)
//   Pico WH         → NFC + Ultras. + Temp (ESCLAVO SENSORES) Serial  (RX=3,  TX=1)
// ═══════════════════════════════════════════════════

TFT_eSPI tft = TFT_eSPI();
Preferences preferences;

const byte ROWS = 4, COLS = 4;
char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};
byte rowPins[ROWS] = {26, 25, 33, 32};
byte colPins[COLS] = {13, 12, 14, 27};
Keypad keypad = Keypad(makeKeymap(keys), colPins, rowPins, ROWS, COLS);

// GPIO 21 = TFT_DC (User_Setup.h) → GPIO 2 queda libre para LED/Relé de luces:
const int LED_PIN = 2;

// ─── DATOS DE SENSORES (recibidos del Pico WH por Serial) ────────────────────
// Protocolo: líneas de texto terminadas en '\n'
//   NFC:<uid_hex>   → tarjeta detectada
// ─── PINES UART EN ESP32 MAESTRO ─────────────────────────────────────────────
// Serial2 → ESP32 Esclavo de Motores (RX=16, TX=17) [Fijo e intacto]
#define MOTOR_UART_RX 16
#define MOTOR_UART_TX 17

// Serial1 → Raspberry Pi Pico WH (Sensores) en pines libres y seguros (RX=19, TX=22)
#define PICO_UART_RX 19
#define PICO_UART_TX 22
HardwareSerial PicoWH(1); // Serial1 -> Pico WH sensores (RX=GPIO19, TX=GPIO22)

String picoUartBuf = "";       // Buffer para parsear líneas del Pico WH
float picoTemperatura = -99.0; // Última temperatura recibida del Pico WH
float picoDistancia   = -1.0;  // Última distancia recibida del Pico WH
String picoNfcUid     = "";    // Último UID NFC recibido del Pico WH

// ─── VARIABLES DE DISTANCIA (ahora vienen del Pico WH) ───────────────────────
float distanciaInicial = 0.0, distanciaFinal = 0.0;
float prevM1 = 0.0, prevM2 = 0.0;
const float REPOSO_MIN_CM = 30.0; // Margen de reposo / bandeja vacía: 30.0 a 35.0 cm
const float REPOSO_MAX_CM = 35.0; // Menor a 30cm o mayor a 35cm -> PRODUCTO ENTREGADO
// ─────────────────────────────────────────────────────────────────────────────

// ================= CONFIGURACION SISTEMA ==================
// Dominio público NGROK para el código QR (que escanean los celulares con 4G):
String      NGROK_DOMAIN       = "passivism-sighing-condense.ngrok-free.dev";

// Conexión interna del ESP32 hacia el servidor central de la máquina (Laptop):
// false: comunicación local directa con la Laptop (10.42.0.1) -> 2ms respuesta, sin caídas SSL
// true:  fuerza al ESP32 a salir por ngrok cloud
const bool  USE_NGROK_FOR_API  = false;

const char* WIFI_SSID          = "ar-HP-Laptop-15-da2xxx";
const char* WIFI_PASSWORD      = "123456789";
String      SERVER_IP          = "10.42.0.1";
const char* MACHINE_ID         = "MACHINE-001";
const int   WEBHOOK_PORT       = 8081;
const unsigned long POLL_INTERVAL_MS      = 1500;
const unsigned long TELEMETRY_INTERVAL_MS = 5000;
// ==========================================================

String qrBaseUrl() {
  // EL CÓDIGO QR SIEMPRE LLEVA NGROK para que cualquier teléfono lo abra desde internet 4G/5G
  return String("https://") + NGROK_DOMAIN + "/p/8010";
}

String baseUrl() {
  if (USE_NGROK_FOR_API) return String("https://") + NGROK_DOMAIN + "/p/8010";
  return String("http://") + SERVER_IP + ":8010";
}

String vendingUrl() {
  if (USE_NGROK_FOR_API) return String("https://") + NGROK_DOMAIN + "/p/8040";
  return String("http://") + SERVER_IP + ":8040";
}

String iotUrl() {
  if (USE_NGROK_FOR_API) return String("https://") + NGROK_DOMAIN + "/p/8050";
  return String("http://") + SERVER_IP + ":8050";
}

// Certificado Root CA oficial de Let's Encrypt (ISRG Root X1) que firma *.ngrok-free.dev
const char* LETSE_ENCRYPT_CA = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
)EOF";

const char *alpnProtocols[] = {"http/1.1", NULL};

void setupHttpClient(HTTPClient &http, WiFiClientSecure &client, const String &url) {
  if (url.startsWith("https://")) {
    client.setCACert(LETSE_ENCRYPT_CA);
    client.setAlpnProtocols(alpnProtocols);
    client.setHandshakeTimeout(30); // 30s para handshake TLS mbedTLS
    http.begin(client, url);
  } else {
    http.begin(url);
  }
  http.setConnectTimeout(15000); // 15s para TCP connect + TLS (evita timeout por defecto de 5s)
  http.setTimeout(15000);        // 15s para transferencias HTTP
  http.addHeader("ngrok-skip-browser-warning", "1");
  http.addHeader("User-Agent", "ESP32-Vending");
}

WebServer webhookServer(WEBHOOK_PORT);
String currentTxId = "", inputCodigo = "", precioSeleccionado = "10.00";
String currentSessionCode = "-----";
int currentCodeSecondsLeft = 45;
unsigned long lastPoll = 0;
unsigned long lastPollCommands = 0;
unsigned long lastTelemetry    = 0;
unsigned long lastActivityTime = 0;
unsigned long lastSessionCodePoll = 0;
unsigned long lastPendingActionPoll = 0;
unsigned long lastCatalogPoll = 0;
bool webhookPaymentPending = false;
bool waitingForPayment = false;


// --- UTILIDADES ---
void mostrarCatalogo(bool limpiarPantallaCompleta = true); // Prototipo

void resetState() {
  inputCodigo = "";
  currentTxId = "";
  waitingForPayment = false;
  lastActivityTime = millis();
  mostrarCatalogo();
}

void pedirIP() {
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_GREEN);
  tft.setTextSize(2);
  tft.setCursor(10, 5);
  tft.println("MI IP ESP32:");
  tft.setCursor(10, 25);
  tft.setTextColor(TFT_YELLOW);
  tft.println(WiFi.localIP());

  tft.setCursor(10, 55);
  tft.setTextColor(TFT_GREEN);
  tft.println("IP SERVER:");
  tft.setCursor(10, 75);
  tft.setTextColor(TFT_WHITE);
  tft.setTextSize(1);
  tft.println("Use '*' para punto '.'");
  tft.println("Use 'D' confirmar, 'C' borrar");
  tft.drawRect(10, 100, 220, 40, TFT_WHITE);
  
  String nuevaIP = "";
  while (true) {
    char key = keypad.getKey();
    if (key) {
      if (key == 'D') {
        if (nuevaIP.length() > 7) { 
          SERVER_IP = nuevaIP;
          preferences.begin("grog", false);
          preferences.putString("server_ip", SERVER_IP); 
          preferences.end();
          break;
        }
      } else if (key == '*') {
        nuevaIP += ".";
      } else if (key == 'C') {
        if (nuevaIP.length() > 0) nuevaIP.remove(nuevaIP.length() - 1);
      } else if (key >= '0' && key <= '9') {
        nuevaIP += key;
      }
      
      tft.fillRect(15, 105, 210, 30, TFT_BLACK);
      tft.setCursor(20, 110);
      tft.setTextColor(TFT_YELLOW);
      tft.setTextSize(2);
      tft.print(nuevaIP);
      tft.print("_");
    }
    delay(10);
  }
  tft.fillScreen(TFT_BLACK);
  tft.setCursor(10, 100);
  tft.setTextColor(TFT_GREEN);
  tft.println("IP CONFIGURADA!");
  delay(1000);
}

void mostrarTeclaEnPantalla(char key) {
  int rectWidth = 40, rectHeight = 40;
  int xPos = tft.width() - rectWidth - 5, yPos = 5; // Arriba a la derecha
  tft.fillRect(xPos, yPos, rectWidth, rectHeight, TFT_BLUE);
  tft.drawRect(xPos, yPos, rectWidth, rectHeight, TFT_WHITE);
  tft.setTextColor(TFT_WHITE, TFT_BLUE); tft.setTextSize(3);
  tft.setCursor(xPos + 12, yPos + 10); tft.print(key);
}

/**
 * Prueba de comunicación TX/RX bidireccional con la Raspberry Pi Pico WH.
 * Se ejecuta si TEST_COMM_PICO_ENABLED está en true.
 */
void probarComunicacionPicoWH() {
  if (!TEST_COMM_PICO_ENABLED) {
    Serial.println("[TEST-UART] Prueba con Pico WH deshabilitada (TEST_COMM_PICO_ENABLED = false).");
    return;
  }

  Serial.println("\n========================================================");
  Serial.println("[TEST-UART] === PRUEBA DE COMUNICACIÓN CON PICO WH ===");
  Serial.println("[TEST-UART] Enviando 'PING' por Serial1 (TX=GPIO22, RX=GPIO19)...");
  
  // Limpiar buffer
  while (PicoWH.available()) PicoWH.read();

  PicoWH.println("PING");
  unsigned long start = millis();
  bool pongRecibido = false;
  String respuesta = "";

  while (millis() - start < 1500) {
    if (PicoWH.available()) {
      char c = PicoWH.read();
      if (c == '\n') {
        respuesta.trim();
        if (respuesta == "PONG") {
          pongRecibido = true;
          break;
        }
        respuesta = "";
      } else {
        respuesta += c;
      }
    }
    delay(5);
  }

  if (pongRecibido) {
    Serial.println("[TEST-UART] >>> [OK] ¡ÉXITO! Recibido 'PONG' de Pico WH. TX/RX operando correctamente. <<<");
  } else {
    Serial.println("[TEST-UART] >>> [FALLO / TIMEOUT] No se recibió 'PONG' del Pico WH.");
    Serial.println("[TEST-UART] Verificar: 1) RX Pico(GP5) <-> TX ESP32(GPIO22). 2) TX Pico(GP4) <-> RX ESP32(GPIO19). 3) GND común.");
  }
  Serial.println("========================================================\n");
}

/**
 * Procesa mensajes entrantes del Pico WH (sensores) por PicoWH (Serial1).
 * Protocolo: "NFC:<uid>\n" | "DIST:<cm>\n" | "TEMP:<C>\n" | "PONG\n"
 * Llama esto en cada iteración del loop().
 */
void procesarPicoWH() {
  while (PicoWH.available()) {
    char c = PicoWH.read();
    if (c == '\n') {
      picoUartBuf.trim();
      if (picoUartBuf.startsWith("DIST:")) {
        picoDistancia = picoUartBuf.substring(5).toFloat();
        Serial.printf("[PICO] Distancia: %.1f cm\n", picoDistancia);
      } else if (picoUartBuf.startsWith("TEMP:")) {
        if (ENABLE_TEMP_READING) {
          picoTemperatura = picoUartBuf.substring(5).toFloat();
          Serial.printf("[PICO] Temperatura: %.1f C\n", picoTemperatura);
        } else {
          Serial.println("[PICO] Temperatura recibida pero ignorada (ENABLE_TEMP_READING = false).");
        }
      } else if (picoUartBuf.startsWith("NFC:")) {
        picoNfcUid = picoUartBuf.substring(4);
        Serial.printf("[PICO] NFC UID: %s\n", picoNfcUid.c_str());
        enviarNfcScan(picoNfcUid);
      } else if (picoUartBuf.indexOf("PONG") != -1) {
        Serial.println("[PICO] >>> ¡PONG RECIBIDO! Pico WH responde correctamente. <<<");
      }
      picoUartBuf = "";
    } else {
      picoUartBuf += c;
    }
  }
}

void enviarNfcScan(const String &uid) {
  if (WiFi.status() != WL_CONNECTED) return;
  WiFiClientSecure client;
  HTTPClient http;
  String url = iotUrl() + "/api/v1/iot/nfc/scan";
  setupHttpClient(http, client, url);
  http.addHeader("Content-Type", "application/json");
  String body = "{\"machine_id\":\"" + String(MACHINE_ID) + "\",\"uid\":\"" + uid + "\",\"source\":\"PICO_WH\"}";
  int code = http.POST(body);
  Serial.printf("[NFC HTTP] Enviado UID al backend IoT. Codigo: %d\n", code);
  http.end();
}

/**
 * Solicita una medida de distancia urgente al Pico WH y espera respuesta.
 * Limpia el buffer previo para evitar datos residuales en la pila UART.
 * Devuelve distancia en cm, o -1.0 si hay timeout.
 */
float medirDistancia() {
  // 1. Limpiar buffer viejo acumulado en la pila UART
  while (PicoWH.available()) {
    PicoWH.read();
  }

  // 2. Enviar orden de medición
  PicoWH.println("MEDIR");
  unsigned long t = millis();
  String buf = "";
  
  // 3. Esperar respuesta de la Pico WH (máximo 200 ms)
  while (millis() - t < 200) {
    while (PicoWH.available()) {
      char c = PicoWH.read();
      if (c == '\n') {
        buf.trim();
        if (buf.startsWith("DIST:")) {
          float dist = buf.substring(5).toFloat();
          if (dist > 0.0) {
            picoDistancia = dist;
            return picoDistancia;
          }
        }
        buf = "";
      } else {
        buf += c;
      }
    }
    delay(2);
  }
  return -1.0; // Timeout real
}

void dibujarMonitores(float temp = -1.0) {
  // Monitores actuales (Abajo a la derecha)
  int x = tft.width() - 85, y = tft.height() - 65; 
  tft.fillRect(x, y, 80, 60, TFT_BLACK); tft.drawRect(x, y, 80, 60, TFT_DARKGREY);
  tft.setTextSize(1);
  tft.setTextColor(TFT_CYAN); tft.setCursor(x+5, y+5); tft.print("M1:"); tft.print(distanciaInicial,1);
  tft.setTextColor(TFT_MAGENTA); tft.setCursor(x+5, y+25); tft.print("M2:"); tft.print(distanciaFinal,1);
  if (temp > -1.0) {
    tft.setTextColor(TFT_YELLOW); tft.setCursor(x+5, y+45); tft.print("T:"); tft.print(temp,1); tft.print("C");
  }

  // Histórico / Datos anteriores (Arriba a la derecha)
  int hX = tft.width() - 120, hY = 5;
  tft.fillRect(hX, hY, 115, 25, TFT_BLACK);
  tft.drawRect(hX, hY, 115, 25, TFT_DARKGREY);
  tft.setTextSize(1);
  tft.setTextColor(TFT_LIGHTGREY);
  tft.setCursor(hX+5, hY+10);
  tft.printf("P:M1:%.1f M2:%.1f", prevM1, prevM2);
}

String extractTxId(const String& body) {
  int i = body.indexOf("\"tx_id\":\"");
  if (i < 0) i = body.indexOf("\"tx_id\": \"");
  if (i < 0) i = body.indexOf("\"id\":\"");
  if (i < 0) return "";
  int start = body.indexOf("\"", i + 8) + 1;
  return body.substring(start, body.indexOf("\"", start));
}

// Envía telemetría usando la temperatura recibida del Pico WH
void enviarTelemetria() {
  if (picoTemperatura == -99.0 || WiFi.status() != WL_CONNECTED) return; // Sin dato válido aún
  
  // 1. Enviar al Orquestador
  WiFiClientSecure client;
  HTTPClient http;
  String url = baseUrl() + "/api/v1/machines/" + MACHINE_ID + "/telemetry";
  setupHttpClient(http, client, url);
  http.addHeader("Content-Type", "application/json");
  String body = "{\"temperature\":" + String(picoTemperatura) + ", \"ip\":\"" + WiFi.localIP().toString() + "\"}";
  http.POST(body);
  http.end();

  // 2. Enviar al IoT Bridge Service
  WiFiClientSecure clientIot;
  HTTPClient httpIot;
  String urlIot = iotUrl() + "/api/v1/iot/telemetry";
  setupHttpClient(httpIot, clientIot, urlIot);
  httpIot.addHeader("Content-Type", "application/json");
  String bodyIot = "{\"machine_id\":\"" + String(MACHINE_ID) + "\",\"temperature\":" + String(picoTemperatura) + ",\"humidity\":40.0,\"motor_status\":\"OK\",\"status\":\"online\"}";
  httpIot.POST(bodyIot);
  httpIot.end();
}

void dibujarBannerCodigo() {
  // Banner de emparejamiento superior
  tft.fillRect(0, 0, tft.width(), 38, TFT_NAVY);
  tft.drawFastHLine(0, 38, tft.width(), TFT_WHITE);
  
  tft.setTextSize(1);
  tft.setTextColor(TFT_WHITE);
  tft.setCursor(6, 6);
  tft.print("APP GROG: COMPRA CON CODIGO");
  
  tft.setTextSize(2);
  tft.setCursor(6, 18);
  tft.setTextColor(TFT_YELLOW);
  tft.printf("PIN: %s", currentSessionCode.c_str());
  
  tft.setTextSize(1);
  tft.setTextColor(TFT_CYAN);
  tft.setCursor(tft.width() - 55, 22);
  tft.printf("%ds", currentCodeSecondsLeft);
}

void fetchSessionCode() {
  if (WiFi.status() != WL_CONNECTED) return;
  WiFiClientSecure client;
  HTTPClient http;
  String url = vendingUrl() + "/api/v1/machines/" + MACHINE_ID + "/session-code";
  setupHttpClient(http, client, url);
  int httpCode = http.GET();
  if (httpCode == 200) {
    String payload = http.getString();
    int cPos = payload.indexOf("\"code\":\"");
    if (cPos != -1) {
      int cStart = cPos + 8;
      currentSessionCode = payload.substring(cStart, payload.indexOf("\"", cStart));
    }
    int sPos = payload.indexOf("\"seconds_left\":");
    if (sPos != -1) {
      int sStart = payload.indexOf(":", sPos) + 1;
      while (sStart < payload.length() && payload[sStart] == ' ') sStart++;
      int sEnd = sStart;
      while (sEnd < payload.length() && payload[sEnd] >= '0' && payload[sEnd] <= '9') sEnd++;
      currentCodeSecondsLeft = payload.substring(sStart, sEnd).toInt();
    }
  } else {
    char sslErr[128] = {0};
    int errCode = client.lastError(sslErr, sizeof(sslErr));
    Serial.printf("[SESSION CODE] ERROR HTTP: %d | SSL code: %d (%s)\n", httpCode, errCode, sslErr);
  }
  http.end();
}

void mostrarCatalogo(bool limpiarPantallaCompleta) {
  if (limpiarPantallaCompleta) {
    tft.fillScreen(TFT_BLACK);
    fetchSessionCode();
    dibujarBannerCodigo();
  }
  
  if (WiFi.status() != WL_CONNECTED) {
    tft.setTextColor(TFT_RED); tft.setCursor(10, 50); tft.println("SIN CONEXION WIFI");
    return;
  }

  WiFiClientSecure client;
  HTTPClient http;
  String url = vendingUrl() + "/api/v1/machines/" + MACHINE_ID + "/inventory?include_images=false&only_enabled=true";
  
  setupHttpClient(http, client, url);
  int httpCode = http.GET();
  
  // Limpiar solo el área de productos entre banner y pie de pantalla
  tft.fillRect(0, 39, tft.width(), tft.height() - 39 - 45, TFT_BLACK);

  if (httpCode == 200) {
    String payload = http.getString(); 
    int pos = 0, y = 48;
    while ((pos = payload.indexOf("\"slot\":", pos)) != -1 && y < (tft.height() - 45)) {
      yield(); 
      int sS = payload.indexOf("\"", pos + 7) + 1; 
      String slot = payload.substring(sS, payload.indexOf("\"", sS));
      int nPos = payload.indexOf("\"product_name\":", pos); 
      int nS = payload.indexOf("\"", nPos + 15) + 1; 
      String name = payload.substring(nS, payload.indexOf("\"", nS));
      int pPos = payload.indexOf("\"price\":", pos); 
      int pS = payload.indexOf(":", pPos) + 1; 
      while(pS < payload.length() && (payload[pS] == ' ' || payload[pS] == '\"')) pS++;
      int pE = pS; 
      while(pE < payload.length() && payload[pE] != ',' && payload[pE] != '}' && payload[pE] != '\"' && payload[pE] != ' ') pE++;
      String price = payload.substring(pS, pE);
      
      // Doble verificación: comprobar is_enabled en este bloque
      int ePos = payload.indexOf("\"is_enabled\":", pos);
      bool isEnabled = true;
      if (ePos != -1 && ePos < pos + 300) {
        if (payload.indexOf("false", ePos) != -1 && payload.indexOf("false", ePos) < ePos + 10) {
          isEnabled = false;
        }
      }

      if (isEnabled) {
        tft.setCursor(10, y); tft.setTextSize(2);
        tft.setTextColor(TFT_YELLOW); tft.print(slot);
        tft.setTextColor(TFT_WHITE); tft.print(": "); 
        tft.print(name.substring(0, 9)); 
        tft.setTextColor(TFT_GREEN); tft.print(" Bs"); tft.println(price);
        y += 26;
      }
      pos = pPos + 5; 
    }
  } else {
    char sslErr[128] = {0};
    int errCode = client.lastError(sslErr, sizeof(sslErr));
    Serial.printf("[CATALOGO] ERROR HTTP: %d | SSL code: %d (%s) | Free Heap: %d\n",
                  httpCode, errCode, sslErr, ESP.getFreeHeap());
    tft.setCursor(10, 50); tft.setTextColor(TFT_RED); tft.print("ERROR: "); tft.print(httpCode);
  }
  http.end();
  
  // LEYENDA DINAMICA EN CATALOGO
  tft.fillRect(0, tft.height()-45, tft.width(), 45, TFT_BLACK);
  tft.drawFastHLine(0, tft.height()-45, tft.width(), TFT_DARKGREY);
  tft.setTextSize(1); tft.setTextColor(TFT_LIGHTGREY); 
  tft.setCursor(10, tft.height()-35); tft.print("D: COMPRAR   *: LIMPIAR");
  tft.setCursor(10, tft.height()-20); tft.print("CODIGOS: A1-A3, A7, C1-C3, C7");
  
  dibujarMonitores();
}

bool lightsOn = false;


void toggleLights() {
  lightsOn = !lightsOn;
  digitalWrite(LED_PIN, lightsOn ? HIGH : LOW);
  Serial.print("Luces: "); Serial.println(lightsOn ? "ENCENDIDAS" : "APAGADAS");
}

void registrarIntencionYMostrarQR() {
  lastActivityTime = millis();
  WiFiClientSecure client;
  HTTPClient http;
  
  // 1. Obtener info del slot y verificar si está habilitado
  String slotUrl = vendingUrl() + "/api/v1/machines/" + MACHINE_ID + "/slots/" + inputCodigo;
  setupHttpClient(http, client, slotUrl);
  int httpCode = http.GET();
  bool canBuy = false;
  
  Serial.printf("[SLOT-CHECK] Consultando: %s | HTTP: %d\n", slotUrl.c_str(), httpCode);
  if (httpCode == 200) {
    String payload = http.getString(); 
    Serial.printf("[SLOT-CHECK] Payload: %s\n", payload.c_str());
    // Buscar "is_enabled":true
    if (payload.indexOf("\"is_enabled\":true") != -1 || payload.indexOf("\"is_enabled\": true") != -1) {
      canBuy = true;
      // Extraer precio
      int pP = payload.indexOf("\"price\":"); 
      if (pP != -1) {
        int pS = payload.indexOf(":", pP) + 1;
        while(pS < payload.length() && (payload[pS] == ' ' || payload[pS] == '\"')) pS++;
        int pE = pS;
        while(pE < payload.length() && payload[pE] != ',' && payload[pE] != '}' && payload[pE] != '\"' && payload[pE] != ' ') pE++;
        precioSeleccionado = payload.substring(pS, pE);
      }
    }
  }
  http.end();

  if (!canBuy) {
    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_RED); tft.setTextSize(2);
    tft.setCursor(10, 80);
    tft.println("SLOT NO DISPONIBLE");
    tft.setTextColor(TFT_WHITE);
    tft.println("POR FAVOR ELIJA OTRO");
    delay(3000);
    resetState();
    return;
  }

  // 2. Registrar transaccion en orquestador
  WiFiClientSecure clientTx;
  HTTPClient httpTx;
  String initUrl = baseUrl() + "/api/v1/transactions/init";
  setupHttpClient(httpTx, clientTx, initUrl);
  httpTx.addHeader("Content-Type", "application/json");
  String regBody = "{\"machine_id\":\"" + String(MACHINE_ID) + "\",\"product_id\":\"" + inputCodigo + "\",\"amount\":" + precioSeleccionado + "}";
  if (httpTx.POST(regBody) == 200) {
    currentTxId = extractTxId(httpTx.getString());
  }
  httpTx.end();

  distanciaInicial = medirDistancia();
  tft.fillScreen(TFT_WHITE); tft.setTextColor(TFT_BLACK); tft.setTextSize(2); tft.setCursor(10, 5);
  tft.printf("PAGAR %s: Bs%s", inputCodigo.c_str(), precioSeleccionado.c_str());
  
  // 3. Generar y mostrar QR (Siempre con dominio público NGROK para escaneo móvil desde celulares)
  String payload = qrBaseUrl() + "/init/" + MACHINE_ID + "?product_id=" + inputCodigo + "&amount=" + precioSeleccionado;
  esp_qrcode_config_t cfg = ESP_QRCODE_CONFIG_DEFAULT();
  cfg.display_func = [](esp_qrcode_handle_t qrcode) {
    int qrSize = esp_qrcode_get_size(qrcode); int scale = 4;
    int sX = (tft.width() - (qrSize * scale)) / 2; int sY = (tft.height() - (qrSize * scale)) / 2 + 10;
    for (int y = 0; y < qrSize; y++) {
      for (int x = 0; x < qrSize; x++) {
        tft.fillRect(sX + (x * scale), sY + (y * scale), scale, scale, esp_qrcode_get_module(qrcode, x, y) ? TFT_BLACK : TFT_WHITE);
      }
    }
  };
  esp_qrcode_generate(&cfg, payload.c_str());
  
  // LEYENDA EN PANTALLA QR
  tft.fillRect(0, tft.height()-30, tft.width(), 30, TFT_BLACK);
  tft.setTextColor(TFT_YELLOW); tft.setTextSize(1);
  tft.setCursor(20, tft.height()-20); tft.print("PRESIONE '*' PARA CANCELAR");
  
  waitingForPayment = true;
  dibujarMonitores();
}
void processPaidTransaction(String txId) {
  Serial.println("\n[SYSTEM] --- INICIANDO PROCESO DE DESPACHO (MODO RÁFAGA) ---");
  Serial.printf("[SYSTEM] TX ID: %s | Slot: %s\n", txId.c_str(), inputCodigo.c_str());

  // Guardar históricos para la pantalla antes de actualizar
  prevM1 = distanciaInicial;
  prevM2 = distanciaFinal;

  // Asegurar que M1 (Base) es válida
  if (distanciaInicial > 390.0) {
    distanciaInicial = medirDistancia();
    Serial.printf("[SENSOR] Calibrando M1 (Base): %.2f cm\n", distanciaInicial);
  }

  waitingForPayment = false;
  tft.fillScreen(TFT_BLACK); 
  tft.setTextColor(TFT_YELLOW); tft.setTextSize(2); tft.setCursor(10, 20);
  tft.println("PAGO CONFIRMADO"); 
  tft.setTextColor(TFT_WHITE); tft.println("INICIANDO MOTOR...");

  // 1. MANDAR SEÑAL AL ESCLAVO
  Serial.printf("[SLAVE] >>> Enviando MOVE:%s\n", inputCodigo.c_str());
  Serial2.println("MOVE:" + inputCodigo);

  // 2. MONITOREO EN RÁFAGA CON CONTEO REGRESIVO (10 SEGUNDOS)
  distanciaFinal = distanciaInicial; // M2 empieza siendo igual a la base
  bool detectado = false;
  unsigned long startBurst = millis();
  int lastSec = -1;

  Serial.println("[SENSOR] Iniciando ráfaga de medidas (10s)...");

  while (millis() - startBurst < 10000) {
    unsigned long elapsed = millis() - startBurst;
    int secondsLeft = 10 - (elapsed / 1000);

    // Actualizar cuenta regresiva en pantalla (sin parpadeo)
    if (secondsLeft != lastSec) {
      lastSec = secondsLeft;
      tft.fillRect(0, 80, tft.width(), 40, TFT_BLACK); // Limpiar franja del contador
      tft.setCursor(20, 90);
      tft.setTextColor(TFT_CYAN); tft.setTextSize(2);
      tft.printf("VIGILANDO: %ds", secondsLeft);
      Serial.printf("[SYSTEM] Tiempo restante: %ds...\n", secondsLeft);
    }

    // Medida a alta velocidad
    float d = medirDistancia();
    
    // Mostramos cada medida en el serial para análisis si es válida
    if (d > 0.0) {
      Serial.printf("[RAFAGA] Dist: %.2f cm\n", d);

      // Solo procesamos lecturas físicas coherentes
      if (d >= 2.0 && d <= 50.0) {
        distanciaFinal = d;

        // Regla: si la distancia es menor a 30cm o mayor a 35cm, cayó un producto
        if (d < REPOSO_MIN_CM || d > REPOSO_MAX_CM) {
          detectado = true;
          Serial.printf("[SENSOR] 🎯 ¡Producto detectado fuera de reposo! (Medida: %.2f cm)\n", d);
        }
      }
    }

    // Revisar si el esclavo responde DONE mientras medimos
    if (Serial2.available()) {
      String resp = Serial2.readStringUntil('\n');
      resp.trim();
      if (resp == "DONE") Serial.println("[SLAVE] Motor terminó su giro.");
    }

    delay(20); // Pausa óptima para la ráfaga
  }

  // 3. DETERMINAR RESULTADO FINAL
  // Si la distancia final quedó dentro del margen de reposo (30 a 35 cm) y nunca hubo caída detectada:
  // la bandeja sigue vacía en reposo -> NO SE ENTREGÓ EL PRODUCTO.
  if (distanciaFinal >= REPOSO_MIN_CM && distanciaFinal <= REPOSO_MAX_CM) {
    detectado = false;
    Serial.printf("[SENSOR] ⚠️ M2 final (%.2f cm) está en margen de reposo (%.1f-%.1f cm). NO ENTREGADO.\n", 
                  distanciaFinal, REPOSO_MIN_CM, REPOSO_MAX_CM);
  } else if (distanciaFinal > 0.5 && (distanciaFinal < REPOSO_MIN_CM || distanciaFinal > REPOSO_MAX_CM)) {
    // Si la lectura final quedó alterada fuera de [30, 35] cm -> Confirmar entrega
    detectado = true;
  }

  Serial.printf("[SENSOR] RESUMEN -> M1 (Base): %.2f | M2 (Final): %.2f | Margen Reposo: %.1f-%.1f cm | Entregado: %s\n", 
                distanciaInicial, distanciaFinal, REPOSO_MIN_CM, REPOSO_MAX_CM, detectado ? "SI" : "NO");

  // MOSTRAR RESULTADO EN TFT
  tft.fillScreen(TFT_BLACK);
  if (detectado) {
    tft.setCursor(10, 80);
    tft.setTextColor(TFT_GREEN); tft.setTextSize(3); tft.println("¡EXITO!");
    tft.setTextSize(2); tft.println("PRODUCTO ENTREGADO");
    Serial.println("[RESULT] Despacho exitoso (Detección en ráfaga).");
  } else {
    tft.setCursor(10, 60);
    tft.setTextColor(TFT_RED); tft.setTextSize(3); tft.println("ERROR");
    tft.setTextSize(2);
    tft.println("NO SE DETECTO");
    tft.println("LA CAIDA DEL");
    tft.println("PRODUCTO");
    Serial.println("[RESULT] No se detectó ninguna caída significante.");
  }

  // 4. NOTIFICAR AL BACKEND (M1 y M2-mínimo)
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClientSecure client;
    HTTPClient http;
    String endPoint = detectado ? "/dispense-result" : "/refund";
    String url = baseUrl() + "/api/v1/transactions/" + txId + endPoint;
    
    Serial.printf("[HTTP] Notificando a: %s\n", url.c_str());
    setupHttpClient(http, client, url);
    http.addHeader("Content-Type", "application/json");
    
    // Enviamos M1 como initial_distance y el M2 más bajo como final_distance
    String telemetry = "{\"success\":" + String(detectado?"true":"false") + 
                       ",\"initial_distance\":" + String(distanciaInicial) + 
                       ",\"final_distance\":" + String(distanciaFinal) + "}";
    
    int httpCode = http.POST(telemetry);
    if (httpCode > 0) {
      Serial.printf("[HTTP] Code: %d\n", httpCode);
    }
    http.end();
  }

  Serial.println("[SYSTEM] --- FIN DEL PROCESO ---\n");
  dibujarMonitores();
  delay(3000);
  resetState();
}

void connectWifi() {
  Serial.print("Conectando a: "); Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 30) { 
    delay(500); 
    Serial.print("."); 
    retry++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi OK");
    Serial.printf("  [WIFI] IP asignada: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("  [WIFI] Puerta enlace: %s\n", WiFi.gatewayIP().toString().c_str());
    Serial.printf("  [WIFI] Servidor DNS:  %s\n", WiFi.dnsIP().toString().c_str());
  } else {
    Serial.println("\nError: WiFi no conectado.");
  }
}

void sincronizarHoraNTP() {
  Serial.print("[NTP] Sincronizando fecha/hora para certificados SSL");
  configTime(0, 0, "pool.ntp.org", "time.google.com");
  time_t now = time(nullptr);
  int retry = 0;
  while (now < 1700000000 && retry < 25) {
    delay(400);
    Serial.print(".");
    now = time(nullptr);
    retry++;
  }
  if (now >= 1700000000) {
    struct tm ti;
    gmtime_r(&now, &ti);
    Serial.printf("\n[NTP] OK! Fecha: %04d-%02d-%02d %02d:%02d:%02d UTC\n",
                  ti.tm_year + 1900, ti.tm_mon + 1, ti.tm_mday, ti.tm_hour, ti.tm_min, ti.tm_sec);
  } else {
    Serial.println("\n[NTP] Advertencia: Timeout en NTP (se continuara).");
  }
}

void setup() {
  Serial.begin(115200);
  // Inicializar Serial2 para el Esclavo de Motores (RX=16, TX=17) [Fijo para Motores]
  Serial2.begin(9600, SERIAL_8N1, 16, 17); 
  // Inicializar Serial1 para Pico WH de Sensores en pines seguros (RX=19, TX=22)
  PicoWH.begin(9600, SERIAL_8N1, 19, 22);
  delay(1000);
  Serial.println("--- MASTER INICIADO ---");

  // Test de comunicación con Pico WH (si TEST_COMM_PICO_ENABLED es true)
  probarComunicacionPicoWH();

  pinMode(LED_PIN, OUTPUT);
  
  tft.init(); tft.setRotation(0);
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_CYAN);
  tft.setTextSize(3);
  tft.setCursor(20, 80);
  tft.println("BIENVENIDO");
  tft.setCursor(60, 120);
  tft.setTextColor(TFT_YELLOW);
  tft.println("A GROG");
  
  // Conectar WiFi y sincronizar reloj
  connectWifi();
  sincronizarHoraNTP(); 

  if (USE_NGROK_FOR_API) {
    Serial.printf("Configurado para API NGROK: %s\n", NGROK_DOMAIN.c_str());
    IPAddress resolvedIP;
    Serial.print("[DNS] Verificando resolucion NGROK... ");
    if (WiFi.hostByName(NGROK_DOMAIN.c_str(), resolvedIP)) {
      Serial.printf("OK! IP: %s\n", resolvedIP.toString().c_str());
    }
  } else {
    Serial.printf("[SYSTEM] API interna comunicando por RED LOCAL: http://%s (latencia 2ms, sin errores SSL)\n", SERVER_IP.c_str());
    Serial.printf("[SYSTEM] Dominio NGROK público para QR de pago: https://%s\n", NGROK_DOMAIN.c_str());
  }
  
  webhookServer.on("/payment-confirmed", HTTP_POST, [](){
    String txId = webhookServer.arg("tx_id");
    if (txId.length() > 0) { currentTxId = txId; webhookPaymentPending = true; }
    webhookServer.send(200, "application/json", "{\"ok\":true}");
  });
  
  webhookServer.on("/command", HTTP_POST, [](){
    String cmd = webhookServer.arg("command");
    if (cmd == "toggle_lights") { toggleLights(); }
    else if (cmd == "lights_on") { lightsOn = false; toggleLights(); }
    else if (cmd == "lights_off") { lightsOn = true; toggleLights(); }
    webhookServer.send(200, "application/json", "{\"ok\":true}");
  });

  webhookServer.begin();
  lastActivityTime = millis();
  
  Serial.println("Cargando Catalogo...");
  mostrarCatalogo();
}

void loop() {
  webhookServer.handleClient();
  procesarPicoWH(); // Procesa mensajes de UART de Pico WH (NFC, distancia, temperatura)

  if (webhookPaymentPending) { webhookPaymentPending = false; processPaidTransaction(currentTxId); }
  
  unsigned long now = millis();

  // TEMPORIZADOR DE INACTIVIDAD (1 MINUTO)
  if ((inputCodigo.length() > 0 || waitingForPayment) && (now - lastActivityTime > 60000)) {
    resetState();
  }

  if (now - lastTelemetry >= TELEMETRY_INTERVAL_MS) {
    lastTelemetry = now;
    if (TEST_COMM_PICO_ENABLED) {
      Serial.println("[TEST-UART] Enviando 'PING' periódico a Pico WH por Serial1...");
      PicoWH.println("PING");
    }
    enviarTelemetria();
    dibujarMonitores(picoTemperatura);
  }

  // Polling continuo de pagos pendientes (Para NFC y código QR)
  if (now - lastPoll >= POLL_INTERVAL_MS) {
    lastPoll = now;
    if (WiFi.status() == WL_CONNECTED) {
      WiFiClientSecure client;
      HTTPClient http; 
      setupHttpClient(http, client, baseUrl() + "/api/v1/machines/" + MACHINE_ID + "/next-paid");
      if (http.GET() == 200) {
        String res = http.getString();
        if (res.indexOf("\"tx_id\":\"") != -1) {
          String txId = extractTxId(res);
          // Intentar extraer product_id del JSON (ej: {"item":{"tx_id":"...","product_id":"A1"}})
          int pIdPos = res.indexOf("\"product_id\":\"");
          if (pIdPos != -1) {
            int start = pIdPos + 14;
            String slot = res.substring(start, res.indexOf("\"", start));
            if (slot.length() > 0) inputCodigo = slot;
          }
          if (inputCodigo.length() > 0) {
            processPaidTransaction(txId);
          } else {
            Serial.println("[ERROR] Pago recibido pero no hay product_id ni inputCodigo!");
          }
        }
      }
      http.end();
    }
  }

  // Polling de comandos para luces y actualización de catálogo (Precios)
  if (now - lastPollCommands >= 3000) {
    lastPollCommands = now;
    if (WiFi.status() == WL_CONNECTED) {
      WiFiClientSecure client;
      HTTPClient http;
      setupHttpClient(http, client, baseUrl() + "/api/v1/admin/commands/poll/" + String(MACHINE_ID));
      if (http.GET() == 200) {
        String payload = http.getString();
        // Solo refrescamos si el payload contiene comandos reales (no una lista vacía)
        if (payload.indexOf("\"commands\":[]") == -1) {
          if (payload.indexOf("toggle_lights") != -1) {
            toggleLights();
          }
          if (payload.indexOf("lights_on") != -1) {
            lightsOn = false; toggleLights();
          }
          if (payload.indexOf("lights_off") != -1) {
            lightsOn = true; toggleLights();
          }
          if (payload.indexOf("refresh_inventory_config") != -1) {
            mostrarCatalogo();
          }
        }
      }
      http.end();
    }
  }

  // Polling de acciones pendientes desde la App (ej. Selección remota de slot / Generar QR)
  if (!waitingForPayment && (now - lastPendingActionPoll >= 1000)) {
    lastPendingActionPoll = now;
    if (WiFi.status() == WL_CONNECTED) {
      WiFiClientSecure client;
      HTTPClient http;
      setupHttpClient(http, client, vendingUrl() + "/api/v1/machines/" + MACHINE_ID + "/pending-action");
      if (http.GET() == 200) {
        String act = http.getString();
        if (act.indexOf("\"action\":\"generate_qr\"") != -1) {
          int sPos = act.indexOf("\"slot\":\"");
          if (sPos != -1) {
            int start = sPos + 8;
            String slot = act.substring(start, act.indexOf("\"", start));
            if (slot.length() > 0) {
              Serial.printf("[APP-REMOTE] Slot seleccionado desde celular: %s\n", slot.c_str());
              inputCodigo = slot;
              registrarIntencionYMostrarQR();
            }
          }
        }
      }
      http.end();
    }
  }

  // Refresco periódico del catálogo cada 3s cuando esté en pantalla principal (sin parpadeo)
  if (!waitingForPayment && inputCodigo.length() == 0 && (now - lastCatalogPoll >= 3000)) {
    lastCatalogPoll = now;
    mostrarCatalogo(false);
  }

  // Refresco periódico del código de sesión dinámico cada 5s cuando esté en catálogo
  if (!waitingForPayment && inputCodigo.length() == 0 && (now - lastSessionCodePoll >= 5000)) {
    lastSessionCodePoll = now;
    fetchSessionCode();
    dibujarBannerCodigo();
  }


  char key = keypad.getKey();
  if (key) {
    lastActivityTime = now;
    mostrarTeclaEnPantalla(key);
    
    if (key == 'D') { 
      if (inputCodigo.length() > 0) registrarIntencionYMostrarQR(); 
    }
    else if (key == '*') { 
       resetState(); 
    }
    else {
      // 'A', 'B', 'C' y números se guardan en el código
      inputCodigo += key;
      tft.fillRect(10, 180, 180, 40, TFT_NAVY); tft.drawRect(10, 180, 180, 40, TFT_WHITE);
      tft.setCursor(20, 190); tft.setTextColor(TFT_WHITE); tft.setTextSize(2); tft.print("COD: "); tft.print(inputCodigo);
      dibujarMonitores(picoTemperatura);
    }
  }
}
