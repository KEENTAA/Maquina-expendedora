# 🚀 Guía Definitiva de Despliegue Web y Cloud — Gemelo Digital GROG (Unity 6)

Esta guía explica cómo desplegar el proyecto de Unity para que **no requiera ejecutarse en tu laptop** y cualquier persona (jurado, clientes, inversores) pueda probar la simulación interactiva 3D directamente desde un enlace en su navegador web, conectada al backend real de GROG.

---

## 🌐 Arquitectura del Despliegue

```
                              USUARIO FINAL / JURADO
                                (Navegador Web)
                                       │
                        https://...ngrok-free.dev/unity/
                                       │
                                       ▼
                     ┌───────────────────────────────────┐
                     │     GROG API Gateway (Nginx/Proxy) │
                     └─────────────────┬─────────────────┘
                                       │
               ┌───────────────────────┼───────────────────────┐
               ▼                       ▼                       ▼
      [unity-webgl]          [orchestrator-service]    [vending-service]
       (Puerto 8060)             (Puerto 8010)           (Puerto 8040)
  Simulación WebGL 3D       Transacciones y QR Pay    Inventario y Flota
```

---

## 1. Ajustes de Compatibilidad WebGL Aplicados

1. **Protocolo WebGL vs Serial Nativo:**
   - En [`SerialBridge.cs`](file:///home/ar/Proyectos/GemeloVending/Assets/Scripts/SerialBridge.cs), las librerías `System.IO.Ports` y los hilos POSIX (`/tmp/ttyUNITY`) han sido aislados con `#if !UNITY_WEBGL`.
   - Cuando se ejecuta en WebGL, la simulación funciona en modo **Cloud HTTP/API** mediante `UnityWebRequest`.
2. **Enrutamiento Cloud HTTPS Automático:**
   - En [`MDBArchitectureManager.cs`](file:///home/ar/Proyectos/GemeloVending/Assets/Scripts/MDBArchitectureManager.cs), el Gemelo Digital detecta automáticamente el entorno WebGL y enruta todas las llamadas al gateway público HTTPS:
     - `https://passivism-sighing-condense.ngrok-free.dev/p/8010` (Transaction Orchestrator)
     - `https://passivism-sighing-condense.ngrok-free.dev/p/8040` (Vending Service & QR Provisioning)
   - Se inyecta la cabecera `ngrok-skip-browser-warning: 1` para garantizar conexión transparente.
3. **Escena Principal Registrada:**
   - `Assets/Scenes/VendingScene.unity` fue registrada en `EditorBuildSettings.asset`.
4. **Plugins Excluidos de WebGL:**
   - Las librerías nativas de puerto serie `System.IO.Ports.dll` y `libSystem.IO.Ports.Native.so` han sido configuradas para compilarse exclusivamente en Standalone Linux y no generar conflictos en WebAssembly.

---

## 2. Cómo Compilar la Versión WebGL (1 Clic en Unity)

Debido a que Unity 6 Personal utiliza la sesión activa de Unity Hub:

1. Abre el proyecto en el Editor de Unity desde **Unity Hub**.
2. En la barra superior de menús, verás un nuevo menú:
   👉 **`GROG` > `Compilar WebGL para Despliegue Web (Navegador/itch.io)`**
3. Haz clic en él. Unity compilará el reproductor WebAssembly.
4. Al finalizar la compilación:
   - Se creará la carpeta: `Builds/WebGL/`
   - Se generará automáticamente el archivo ZIP listo para publicar: `Builds/GemeloVending_WebGL.zip`
   - Se copiará automáticamente al contenedor Docker Nginx en: `backend/unity-webgl/dist/`

---

## 3. Opciones para Compartir el Enlace Web

### Opción A: Despliegue en la Nube con itch.io (Gratis y Permanente)
1. Entra a [itch.io](https://itch.io) y crea un nuevo proyecto (*Create new project*).
2. En **Classification**, selecciona: `HTML`.
3. En **Kind of project**, selecciona: `HTML (You have a ZIP file)`.
4. En **Uploads**, sube el archivo generado:
   `Builds/GemeloVending_WebGL.zip`
5. Marca la casilla **This file will be played in the browser**.
6. En dimensiones de ventana, ingresa: `960 x 600` o activa pantalla completa.
7. ¡Guarda y publica! Obtendrás un enlace público permanente tipo `https://tu-nombre.itch.io/grog-vending` que cualquiera puede abrir.

---

### Opción B: Despliegue Inmediato en Docker + Túnel Ngrok
El contenedor Docker de WebGL ya se encuentra activo en tu backend:
* **Puerto local:** `http://localhost:8060`
* **Acceso desde cualquier dispositivo por Internet:**
  `https://passivism-sighing-condense.ngrok-free.dev/unity/`

---

### Opción C: Unity Play (Publicación Directa desde el Editor)
1. En Unity Editor: `File` > `Build and Run` seleccionando WebGL o usando el paquete **WebGL Publisher**.
2. Te entregará un enlace directo de `play.unity.com` para compartir.
