# Grog Platform - Máquina Expendedora Inteligente

Este proyecto es una solución integral para la gestión y operación de máquinas expendedoras inteligentes, integrando hardware (ESP32), una aplicación móvil (Flutter) y una arquitectura de microservicios robusta.

## 🚀 Características Principales

*   **Pago Digital con SimuPay:** Integración nativa con pasarela de pagos mediante códigos QR dinámicos.
*   **Gestión de Reembolsos Automáticos:** Sistema inteligente que detecta fallos en el hardware (sensor ultrasónico) y devuelve el dinero automáticamente a la billetera del usuario.
*   **Arquitectura de Microservicios:**
    *   `auth-service`: Gestión de usuarios y seguridad JWT.
    *   `vending-service`: Control de inventario y slots de la máquina.
    *   `transaction-orchestrator-service`: Cerebro que coordina el pago, el despacho y la telemetría.
    *   `simupay-integration-service`: Puente entre la plataforma Grog y la pasarela SimuPay.
*   **Hardware (ESP32):** Control de motores de pasos (A4988), sensores de caída (HC-SR04), telemetría de temperatura (DHT11) y pantalla TFT para interfaz de usuario.

## 🛠️ Estructura del Proyecto

```text
├── backend/                # Microservicios en Python (FastAPI)
│   ├── auth-service/
│   ├── vending-service/
│   ├── transaction-orchestrator-service/
│   ├── simupay-integration-service/
│   └── iot-bridge-service/ # Firmware ESP32 (Arduino/C++)
├── mobile_app/             # Aplicación móvil en Flutter
└── PaymentGateway-Service/ # API de la Pasarela de Pagos SimuPay
```

## 🔌 Configuración del Hardware

El firmware se encuentra en `backend/iot-bridge-service/esp32_qr_led_flow.ino`.
*   **Keypad:** Selección de productos (A1, A2, etc.) + Tecla 'D' para comprar.
*   **Sensor Ultrasónico:** Detección de caída de producto para validación de transacción.
*   **Motor de Pasos:** Control preciso del despacho.
*   **Seguridad:** Temporizador de inactividad de 1 minuto que retorna al catálogo automáticamente.

## 💻 Instalación (Backend)

1.  Asegúrate de tener Docker y Docker Compose instalados.
2.  Configura las variables de entorno en el archivo `.env` dentro de la carpeta `backend/`.
3.  Ejecuta:
    ```bash
    docker-compose up --build
    ```

## 📱 Aplicación Móvil

La aplicación requiere Flutter SDK. Asegúrate de configurar la IP del servidor en las constantes de la aplicación antes de compilar para Android/iOS.

---
*Desarrollado como parte del proyecto de Arquitectura de Software - Grog Platform.*
