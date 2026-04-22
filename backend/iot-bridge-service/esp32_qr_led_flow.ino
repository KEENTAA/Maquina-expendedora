#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Keypad.h>

// Configura tu red Wi-Fi.
const char* WIFI_SSID = "TU_WIFI";
const char* WIFI_PASSWORD = "TU_PASSWORD";

// IP del backend Grog (host que corre docker compose).
const char* BACKEND_HOST = "192.168.1.20";
const int ORCHESTRATOR_PORT = 8010;
const char* MACHINE_ID = "MACHINE-001";

// Configuración del Keypad (4x4)
const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  {'1','2','3','A'},
  {'4','5','6','B'},
  {'7','8','9','C'},
  {'*','0','#','D'}
};
byte rowPins[ROWS] = {13, 12, 14, 27}; // Pines GPIO para filas
byte colPins[COLS] = {26, 25, 33, 32}; // Pines GPIO para columnas
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// Variables de estado
String inputBuffer = "";
const int LED_PIN = 2;
const unsigned long POLL_INTERVAL_MS = 1500;
unsigned long lastPoll = 0;

String orchestratorBase() {
  return String("http://") + BACKEND_HOST + ":" + String(ORCHESTRATOR_PORT);
}

void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Conectando WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi OK");
}

// NUEVA FUNCION: Consultar producto por slot (Keypad)
void handleKeypadInput(String slotId) {
  HTTPClient http;
  String url = orchestratorBase() + "/api/v1/machines/" + MACHINE_ID + "/slots/" + slotId;
  http.begin(url);
  int code = http.GET();
  
  if (code == 200) {
    String body = http.getString();
    StaticJsonDocument<512> doc;
    deserializeJson(doc, body);
    
    const char* prodName = doc["product_name"];
    float price = doc["price"];
    const char* qrPayload = doc["qr_payload"];

    Serial.println("====================================");
    Serial.printf("PRODUCTO: %s\n", prodName);
    Serial.printf("PRECIO: Bs. %.2f\n", price);
    Serial.printf("QR URL: %s%s\n", orchestratorBase().c_str(), qrPayload);
    Serial.println("Genera el QR con la URL anterior.");
    Serial.println("====================================");
  } else {
    Serial.println("Slot no encontrado o sin stock.");
  }
  http.end();
}

bool fetchNextPaidTransaction(String& txId) {
  HTTPClient http;
  String url = orchestratorBase() + "/api/v1/machines/" + MACHINE_ID + "/next-paid";
  http.begin(url);
  int code = http.GET();
  if (code < 200 || code >= 300) {
    http.end();
    return false;
  }
  String body = http.getString();
  http.end();
  StaticJsonDocument<512> doc;
  deserializeJson(doc, body);
  JsonVariant item = doc["item"];
  if (item.isNull()) { txId = ""; return true; }
  txId = String((const char*)item["tx_id"]);
  return true;
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  connectWifi();
  Serial.println("Esperando entrada de Keypad (ej: A1#)...");
}

void loop() {
  char key = keypad.getKey();
  if (key) {
    if (key == '#') {
      Serial.printf("Procesando Slot: %s\n", inputBuffer.c_str());
      handleKeypadInput(inputBuffer);
      inputBuffer = "";
    } else if (key == '*') {
      inputBuffer = "";
      Serial.println("Buffer limpiado.");
    } else {
      inputBuffer += key;
      Serial.print(key);
    }
  }

  unsigned long now = millis();
  if (now - lastPoll >= POLL_INTERVAL_MS) {
    lastPoll = now;
    String txId;
    if (fetchNextPaidTransaction(txId) && txId.length() > 0) {
      Serial.printf("Pago confirmado! Despachando TX: %s\n", txId.c_str());
      digitalWrite(LED_PIN, HIGH); delay(2000); digitalWrite(LED_PIN, LOW);
      // Aqui enviarias el dispense-result OK al backend
    }
  }
}
