# GROG Digital Twin 3D — Unity Game & Simulation

Gemelo digital interactivo y de alta fidelidad desarrollado en **Unity 6 (6000.6.2f1)** para el ecosistema **GROG Smart Vending**.

## Características del Proyecto
- **3 Máquinas Independientes de Autoservicio:**
  1. `VENDING-01`: Expendedora de snacks con resortes helicoidales paramétricos 3D, física de caída realista por gravedad hacia la tolva receptora, detección por sensor ultrasónico HC-SR04 (de 32.5 cm a 11.4 cm) y ranura de monedas físicas MDB (Nivel 0: Fiduciario).
  2. `COOLER-01`: Refrigerador comercial de bebidas frías mantenido a 4.2 °C con compuerta electromecánica por gravedad.
  3. `COFFEE-01`: Máquina automática de café y bebidas calientes con caldera a 92.4 °C (9.2 bar).
- **Telemetría e Integración en Tiempo Real:**
  - Comunicación bidireccional vía WebSockets y HTTP con el microservicio de orquestación y el backend de vending.
  - Generación de QR dinámico 3D y códigos PIN de activación de 6 dígitos.
  - Modo Instalador y Técnico con botón de reset de fábrica iluminado para vincular/desvincular máquinas desde la app móvil.
- **Soporte de Compilación WebGL:**
  - Compatible con navegadores modernos y desplegable en contenedores Nginx.

## Estructura del Directorio
- `Assets/`: Escenas, scripts C# (`MDBArchitectureManager.cs`, `SerialBridge.cs`), shaders, materiales y prefabs.
- `Packages/`: Configuración del Unity Package Manager y manifiesto de paquetes limpios.
- `ProjectSettings/`: Configuración global del proyecto, tags, capas, físicas y renderizado.
- `compilar_webgl.sh`: Script automatizado para compilar a WebGL.
- `GUIA_DESPLIEGUE.md`: Instrucciones paso a paso para compilación y hosting.

## Cómo Abrir en Unity
1. Abrir **Unity Hub**.
2. Hacer clic en **Add** > **Add project from disk**.
3. Seleccionar esta carpeta (`game`).
4. Abrir con **Unity 6 (6000.6.2f1)** o superior.
