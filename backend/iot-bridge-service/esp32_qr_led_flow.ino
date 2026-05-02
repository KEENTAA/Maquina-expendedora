#include <WiFi.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <TFT_eSPI.h>
#include "qrcode.h"
#include <Keypad.h>
#include <DHT.h> 
#include <Preferences.h> // MEMORIA PERMANENTE

TFT_eSPI tft = TFT_eSPI();
Preferences preferences; // Objeto para manejar la memoria

// ================= CONFIGURACION HARDWARE =================
const byte ROWS = 4, COLS = 4;
char keys[ROWS][COLS] = {
  {'1','2','3','A'},
  {'4','5','6','B'},
  {'7','8','9','C'},
  {'*','0','#','D'}
};
byte rowPins[ROWS] = {17, 16, 14, 27}; 
byte colPins[COLS] = {26, 25, 33, 32}; 
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

const int TRIG_PIN = 13, ECHO_PIN = 34, LED_PIN = 2;
const int STEP_PIN = 21;
const int DIR_PIN = 5;
const int ENABLE_PIN = 22;

#define DHTPIN 19     
#define DHTTYPE DHT11 
DHT dht(DHTPIN, DHTTYPE);

float distanciaInicial = 0.0, distanciaFinal = 0.0;
const float UMBRAL_CAIDA_CM = 3.0;
// ==========================================================

// ================= CONFIGURACION SISTEMA ==================
const char* WIFI_SSID = "DESKTOP-89RKVO8 6072";
const char* WIFI_PASSWORD = "@Y087b91";
String SERVER_IP = "192.168.137.1"; 
const char* MACHINE_ID = "MACHINE-001";
const int WEBHOOK_PORT = 8081;
const unsigned long POLL_INTERVAL_MS = 1500;
const unsigned long TELEMETRY_INTERVAL_MS = 5000; 
// ==========================================================

WebServer webhookServer(WEBHOOK_PORT);
String currentTxId = "", inputCodigo = "", precioSeleccionado = "10.00";
unsigned long lastPoll = 0;
unsigned long lastTelemetry = 0;
unsigned long lastActivityTime = 0; // NUEVO: Para el temporizador de inactividad
bool webhookPaymentPending = false;
bool waitingForPayment = false;

String baseUrl() { return String("http://") + SERVER_IP + ":8010"; }
String vendingUrl() { return String("http://") + SERVER_IP + ":8040"; }

// --- UTILIDADES ---
void connectWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println("\nWiFi OK");
}

void mostrarCatalogo(); // Prototipo

void resetState() {
  distanciaInicial = 0.0;
  distanciaFinal = 0.0;
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
  tft.setCursor(10, 20);
  tft.println("INGRESE IP SERVER:");
  tft.setCursor(10, 50);
  tft.setTextColor(TFT_WHITE);
  tft.setTextSize(1);
  tft.println("Use '*' para el punto '.'");
  tft.println("Use 'D' para confirmar");
  tft.println("Use 'C' para borrar");
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
  int xPos = tft.width() - rectWidth - 5, yPos = tft.height() - 90;
  tft.fillRect(xPos, yPos, rectWidth, rectHeight, TFT_BLUE);
  tft.setTextColor(TFT_WHITE, TFT_BLUE); tft.setTextSize(3);
  tft.setCursor(xPos + 12, yPos + 10); tft.print(key);
}

float medirDistancia() {
  digitalWrite(TRIG_PIN, LOW); delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000); 
  return (duration == 0) ? 999.0 : (duration * 0.0343) / 2.0;
}

void dibujarMonitores(float temp = -1.0) {
  int x = tft.width() - 85, y = tft.height() - 65; 
  tft.fillRect(x, y, 80, 60, TFT_BLACK); tft.drawRect(x, y, 80, 60, TFT_DARKGREY);
  tft.setTextSize(1);
  tft.setTextColor(TFT_CYAN); tft.setCursor(x+5, y+5); tft.print("M1:"); tft.print(distanciaInicial,1);
  tft.setTextColor(TFT_MAGENTA); tft.setCursor(x+5, y+25); tft.print("M2:"); tft.print(distanciaFinal,1);
  if (temp > -1.0) {
    tft.setTextColor(TFT_YELLOW); tft.setCursor(x+5, y+45); tft.print("T:"); tft.print(temp,1); tft.print("C");
  }
}

String extractTxId(const String& body) {
  int i = body.indexOf("\"tx_id\":\"");
  if (i < 0) i = body.indexOf("\"tx_id\": \"");
  if (i < 0) i = body.indexOf("\"id\":\"");
  if (i < 0) return "";
  int start = body.indexOf("\"", i + 8) + 1;
  return body.substring(start, body.indexOf("\"", start));
}

void enviarTelemetria(float temp) {
  HTTPClient http;
  String url = baseUrl() + "/api/v1/machines/" + MACHINE_ID + "/telemetry";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  String body = "{\"temperature\":" + String(temp) + "}";
  http.POST(body);
  http.end();
}

void mostrarCatalogo() {
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_CYAN); tft.setTextSize(2); tft.setCursor(10, 10); tft.println("GROG VENDING");
  tft.drawFastHLine(0, 35, tft.width(), TFT_WHITE);
  
  if (WiFi.status() != WL_CONNECTED) {
    tft.setTextColor(TFT_RED); tft.setCursor(10, 50); tft.println("SIN CONEXION WIFI");
    return;
  }

  HTTPClient http;
  http.setTimeout(3000); 
  String url = vendingUrl() + "/api/v1/machines/" + MACHINE_ID + "/inventory";
  http.begin(url);
  int httpCode = http.GET();
  
  if (httpCode == 200) {
    String payload = http.getString(); 
    int pos = 0, y = 50;
    while ((pos = payload.indexOf("\"slot\":", pos)) != -1 && y < (tft.height() - 40)) {
      yield(); 
      int sS = payload.indexOf("\"", pos + 7) + 1; 
      String slot = payload.substring(sS, payload.indexOf("\"", sS));
      int nPos = payload.indexOf("\"product_name\":", pos); 
      int nS = payload.indexOf("\"", nPos + 15) + 1; 
      String name = payload.substring(nS, payload.indexOf("\"", nS));
      int pPos = payload.indexOf("\"price\":", pos); 
      int pS = pPos + 8; while(payload[pS] == ' ' || payload[pS] == ':') pS++;
      int pE = payload.indexOf(",", pS); if (pE == -1) pE = payload.indexOf("}", pS);
      String price = payload.substring(pS, pE);
      
      tft.setCursor(10, y); tft.setTextSize(2);
      tft.setTextColor(TFT_YELLOW); tft.print(slot);
      tft.setTextColor(TFT_WHITE); tft.print(": "); 
      tft.print(name.substring(0, 10)); 
      tft.setTextColor(TFT_GREEN); tft.print(" Bs"); tft.println(price);
      y += 30; pos = pPos + 5; 
    }
  }
  http.end();
  
  // LEYENDA DINAMICA EN CATALOGO
  tft.fillRect(0, tft.height()-45, tft.width(), 45, TFT_BLACK);
  tft.drawFastHLine(0, tft.height()-45, tft.width(), TFT_DARKGREY);
  tft.setTextSize(1); tft.setTextColor(TFT_LIGHTGREY); 
  tft.setCursor(10, tft.height()-35); tft.print("D: COMPRAR   *: LIMPIAR");
  tft.setCursor(10, tft.height()-20); tft.print("C: CONFIG IP (Mantener)");
  
  dibujarMonitores();
}

void registrarIntencionYMostrarQR() {
  lastActivityTime = millis();
  HTTPClient http;
  
  // 1. Obtener precio actualizado
  http.begin(vendingUrl() + "/api/v1/machines/" + MACHINE_ID + "/inventory");
  if (http.GET() == 200) {
    String payload = http.getString(); 
    int pos = payload.indexOf("\"slot\":\"" + inputCodigo + "\"");
    if (pos != -1) {
      int pP = payload.indexOf("\"price\":", pos); 
      int pS = pP + 8; while(payload[pS] == ' ' || payload[pS] == ':') pS++;
      int pE = payload.indexOf(",", pS); if (pE == -1) pE = payload.indexOf("}", pS);
      precioSeleccionado = payload.substring(pS, pE);
    }
  }
  http.end();

  // 2. Registrar transaccion en orquestador
  http.begin(baseUrl() + "/api/v1/transactions/init");
  http.addHeader("Content-Type", "application/json");
  String regBody = "{\"machine_id\":\"" + String(MACHINE_ID) + "\",\"product_id\":\"" + inputCodigo + "\",\"amount\":" + precioSeleccionado + "}";
  if (http.POST(regBody) == 200) {
    currentTxId = extractTxId(http.getString());
  }
  http.end();

  distanciaInicial = medirDistancia();
  tft.fillScreen(TFT_WHITE); tft.setTextColor(TFT_BLACK); tft.setTextSize(2); tft.setCursor(10, 5);
  tft.printf("PAGAR %s: Bs%s", inputCodigo.c_str(), precioSeleccionado.c_str());
  
  // 3. Generar y mostrar QR
  String payload = baseUrl() + "/init/" + MACHINE_ID + "?product_id=" + inputCodigo + "&amount=" + precioSeleccionado;
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
  waitingForPayment = false;
  tft.fillScreen(TFT_BLACK); tft.setTextColor(TFT_YELLOW); tft.setTextSize(2); tft.setCursor(10, 20);
  tft.println("PAGO CONFIRMADO"); tft.setTextColor(TFT_WHITE); tft.println("DESPACHANDO...");
  
  digitalWrite(LED_PIN, HIGH);
  digitalWrite(ENABLE_PIN, LOW); 
  digitalWrite(DIR_PIN, HIGH);   

  unsigned long startTime = millis();
  int lastSec = -1;
  while (millis() - startTime < 10000) {
    yield(); 
    int remaining = 10 - (int)((millis() - startTime) / 1000);
    if (remaining != lastSec) {
      tft.fillRect(110, 80, 80, 50, TFT_BLACK); 
      tft.setCursor(120, 85); tft.setTextSize(4); tft.setTextColor(TFT_CYAN); 
      tft.print(remaining);
      lastSec = remaining;
    }
    digitalWrite(STEP_PIN, HIGH);
    delayMicroseconds(12500); 
    digitalWrite(STEP_PIN, LOW);
    delayMicroseconds(12500);
  }

  digitalWrite(ENABLE_PIN, HIGH); 
  distanciaFinal = medirDistancia(); 
  
  bool success = (distanciaFinal < (distanciaInicial - UMBRAL_CAIDA_CM));
  
  tft.fillScreen(TFT_BLACK);
  tft.setCursor(10, 50);
  if (success) {
    tft.setTextColor(TFT_GREEN); tft.setTextSize(3); tft.println("¡EXITO!");
    tft.setTextSize(2); tft.setTextColor(TFT_WHITE); tft.println("RECOJA SU PRODUCTO");
  } else {
    tft.setTextColor(TFT_RED); tft.setTextSize(3); tft.println("ERROR");
    tft.setTextSize(2); tft.setTextColor(TFT_YELLOW); tft.println("NO DETECTADO");
    tft.setTextColor(TFT_WHITE); tft.println("REEMBOLSANDO...");
  }

  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(baseUrl() + "/api/v1/transactions/" + txId + (success ? "/dispense-result" : "/refund"));
    http.addHeader("Content-Type", "application/json");
    String telemetry = "{\"success\":" + String(success?"true":"false") + ",\"initial_distance\":" + String(distanciaInicial) + ",\"final_distance\":" + String(distanciaFinal) + "}";
    http.POST(telemetry);
    http.end();
  }

  digitalWrite(LED_PIN, LOW); delay(5000);
  resetState();
}

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT); pinMode(ECHO_PIN, INPUT); pinMode(LED_PIN, OUTPUT);
  pinMode(STEP_PIN, OUTPUT); pinMode(DIR_PIN, OUTPUT); pinMode(ENABLE_PIN, OUTPUT);
  digitalWrite(ENABLE_PIN, HIGH);
  tft.init(); tft.setRotation(1);
  
  preferences.begin("grog", true); 
  SERVER_IP = preferences.getString("server_ip", ""); 
  preferences.end();
  if (SERVER_IP == "") pedirIP();
  
  dht.begin(); 
  connectWifi();
  webhookServer.on("/payment-confirmed", HTTP_POST, [](){
    String txId = webhookServer.arg("tx_id");
    if (txId.length() > 0) { currentTxId = txId; webhookPaymentPending = true; }
    webhookServer.send(200, "application/json", "{\"ok\":true}");
  });
  webhookServer.begin();
  lastActivityTime = millis();
  mostrarCatalogo();
}

void loop() {
  webhookServer.handleClient();
  if (webhookPaymentPending) { webhookPaymentPending = false; processPaidTransaction(currentTxId); }
  
  unsigned long now = millis();

  // TEMPORIZADOR DE INACTIVIDAD (1 MINUTO)
  if ((inputCodigo.length() > 0 || waitingForPayment) && (now - lastActivityTime > 60000)) {
    resetState();
  }

  if (now - lastTelemetry >= TELEMETRY_INTERVAL_MS) {
    lastTelemetry = now;
    float t = dht.readTemperature();
    if (!isnan(t)) { enviarTelemetria(t); dibujarMonitores(t); }
  }

  if (waitingForPayment && (now - lastPoll >= POLL_INTERVAL_MS)) {
    lastPoll = now;
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http; http.begin(baseUrl() + "/api/v1/machines/" + MACHINE_ID + "/next-paid");
      if (http.GET() == 200) {
        String res = http.getString();
        if (res.indexOf("\"tx_id\":\"") != -1) processPaidTransaction(extractTxId(res));
      }
      http.end();
    }
  }

  char key = keypad.getKey();
  if (key) {
    lastActivityTime = now;
    mostrarTeclaEnPantalla(key);
    
    if (key == 'D') { 
      if (inputCodigo.length() > 0) registrarIntencionYMostrarQR(); 
    }
    else if (key == 'C') { // MANTENER PARA CONFIG IP
       pedirIP();
       ESP.restart(); 
    }
    else if (key == '*') { // SOLO '*' PARA CANCELAR/LIMPIAR
       resetState(); 
    }
    else {
      // AHORA 'A' Y 'B' SE GUARDAN EN EL CODIGO (Ej: A1)
      inputCodigo += key;
      tft.fillRect(10, 180, 180, 40, TFT_NAVY); tft.drawRect(10, 180, 180, 40, TFT_WHITE);
      tft.setCursor(20, 190); tft.setTextColor(TFT_WHITE); tft.setTextSize(2); tft.print("COD: "); tft.print(inputCodigo);
      dibujarMonitores();
    }
  }
}
