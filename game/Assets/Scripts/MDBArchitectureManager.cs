using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;

/// <summary>
/// MDBArchitectureManager: Controlador interactivo del Gemelo Digital GROG (FUNTEC 2026).
/// Plataforma Universal de Infraestructura IoT + FinTech para Modernización de Autoservicio.
/// Controla TRES MÁQUINAS FÍSICAMENTE INDEPENDIENTES:
/// 1. VENDING-01: Máquina Expendedora de Snacks y Productos Sólidos (Espirales helicoidales 3D, Drop Tray, HC-SR04).
/// 2. COOLER-01: Máquina de Bebidas Refrigeradas (Gabinete refrigerado independiente a 4.2 °C, estantes con latas/botellas, selección individual).
/// 3. COFFEE-01: Máquina de Café y Bebidas Calientes Especializadas (Tolvas de insumos, caldera a 92 °C, alcoba de erogación).
/// </summary>
public class MDBArchitectureManager : MonoBehaviour
{
    public enum MachineType
    {
        VENDING_SNACKS,
        COLD_BEVERAGES,
        COFFEE
    }

    public enum TransactionState
    {
        IDLE,
        PRODUCT_SELECTED,
        PAYMENT_PENDING,
        PAYMENT_AUTHORIZED,
        DISPENSE_PENDING,
        DISPENSING,
        DELIVERY_VERIFYING,
        PROOF_OF_SERVICE,
        CAPTURE,
        COMPLETED,
        DISPENSE_STATUS_UNKNOWN,
        NO_SERVICE_DETECTED,
        RECOVERY,
        RECONCILIATION,
        SERVICE_FAILED,
        REFUND
    }

    [System.Serializable]
    public class MachineItem
    {
        public string id;
        public string name;
        public string category; // "SNACK", "DRINK", "COFFEE"
        public float price;
        public int stock = 8;
        public int maxStock = 12;
        public Color color = Color.white;
        public string machineId; // "VENDING-01", "COOLER-01", "COFFEE-01"
        public int slotNumber;
        public string itemState = "AVAILABLE"; // AVAILABLE, RESERVED, DISPENSED
    }

    [System.Serializable]
    public struct CameraPreset
    {
        public string name;
        public Vector3 position;
        public Vector3 lookAt;
        public string description;
    }

    [Header("Referencias de Cámara y Puntos de Vista")]
    public Camera mainCamera;
    public int currentViewIndex = 0;

    public CameraPreset[] cameraPresets = new CameraPreset[]
    {
        new CameraPreset
        {
            name = "1. Vista Global (3 Máquinas + GROG Cloud)",
            position = new Vector3(0f, 3.8f, -9.0f),
            lookAt = new Vector3(0f, 2.0f, 0f),
            description = "Vista general de la plataforma universal GROG conectando tres máquinas independientes: Expendedora de Snacks (izq), Refrigerador de Bebidas (centro) y Cafetera (der)."
        },
        new CameraPreset
        {
            name = "2. Máquina 1: Expendedora de Snacks (VENDING-01)",
            position = new Vector3(-3.8f, 1.8f, -3.2f),
            lookAt = new Vector3(-3.8f, 1.7f, 0f),
            description = "VENDING-01: Expendedora tradicional de snacks y productos sólidos con espirales helicoidales 3D, teclado numérico 3x3, LCD y sensor HC-SR04 de caída."
        },
        new CameraPreset
        {
            name = "3. Máquina 2: Bebidas Refrigeradas (COOLER-01)",
            position = new Vector3(0f, 1.8f, -3.0f),
            lookAt = new Vector3(0f, 1.6f, 0f),
            description = "COOLER-01: Gabinete refrigerado independiente con puerta transparente, iluminación LED fría, 4.2 °C, estantes de botellas/latas y botones interactivos de selección."
        },
        new CameraPreset
        {
            name = "4. Máquina 3: Cafetera Especializada (COFFEE-01)",
            position = new Vector3(3.8f, 1.8f, -3.0f),
            lookAt = new Vector3(3.8f, 1.6f, 0f),
            description = "COFFEE-01: Máquina automática de café y bebidas calientes con tolvas de insumos (café, leche, chocolate), caldera a 92 °C, alcoba de erogación y vaso."
        },
        new CameraPreset
        {
            name = "5. GROG Universal Edge & Adaptador Modular",
            position = new Vector3(-1.8f, 3.2f, -3.0f),
            lookAt = new Vector3(-1.8f, 3.2f, 0f),
            description = "Controlador Edge ESP32 desacoplado del Machine Adapter (puertos MDB Level 3, Pulse, Relé/Serial) para retrofitting universal."
        },
        new CameraPreset
        {
            name = "6. GROG Cloud & Proof of Service",
            position = new Vector3(0f, 5.2f, -3.8f),
            lookAt = new Vector3(0f, 5.2f, 0f),
            description = "Plataforma Cloud distribuida: Transaction Orchestrator, pasarela de pago y motor PROOF OF SERVICE multi-evidencia que condiciona la liquidación financiera."
        },
        new CameraPreset
        {
            name = "7. GROG Control Center & Digital Twin AI",
            position = new Vector3(1.8f, 3.2f, -3.0f),
            lookAt = new Vector3(1.8f, 3.2f, 0f),
            description = "Centro de control de flota, réplica digital holográfica y motor de Inteligencia Artificial para mantenimiento predictivo y detección de anomalías."
        }
    };

    [Header("Selección de Máquina Activa")]
    public string activeMachineId = "VENDING-01";
    public MachineType activeMachineType = MachineType.VENDING_SNACKS;

    [Header("Catálogos Independientes")]
    public List<MachineItem> vendingSnackItems = new List<MachineItem>();
    public List<MachineItem> coldDrinkItems = new List<MachineItem>();
    public List<MachineItem> coffeeItems = new List<MachineItem>();

    [Header("Transacción Activa")]
    public MachineItem selectedItem = null;
    public TransactionState currentTxState = TransactionState.IDLE;
    public string currentTxId = "";
    public string transactionStatusMessage = "SISTEMA EN REPOSO (MDB BUS IDLE)";
    public string currentStepNarrator = "Plataforma Universal GROG lista. Seleccione una de las 3 máquinas y un producto para iniciar.";

    [Header("Máquina 1: Expendedora de Snacks (3D)")]
    public Transform snackShelvesParent;
    public Mesh springMesh;
    public Material matSpring;
    [Range(3, 6)]
    public int columnsCount = 3;
    public int rowsCount = 3;

    [Header("Máquina 2: Bebidas Refrigeradas (3D)")]
    public Transform coolerDoorTransform;
    public bool isCoolerDoorOpen = false;
    public TextMesh coolerTempText;
    public float targetCoolerTemp = 4.2f;

    [Header("Máquina 3: Máquina de Café (3D)")]
    public Transform coffeeMachineRoot;
    public Transform coffeeCupTransform;
    public Transform coffeeLiquidStream;
    public TextMesh coffeeStatusText;
    public float coffeeBoilerTemp = 92.4f;

    [Header("Sensores y Proof of Service")]
    public Transform hcSr04SensorTransform;
    public TextMesh distanceGaugeText;
    public Collider dropTriggerCollider;
    public float currentMeasuredDistance = 32.5f;
    public Renderer proofOfServiceBadge;
    public Material matProofIdle;
    public Material matProofVerified;
    public Material matProofFailure;

    [Header("Buses de Datos / LineRenderers")]
    public LineRenderer mdbBusLine;
    public LineRenderer edgeToCloudLine;
    public LineRenderer cloudToTwinLine;

    [Header("Ventana Flotante de Escritorio (Desktop Window)")]
    public bool showUI = true;
    public Rect windowRect = new Rect(20, 50, 480, 600);
    public bool isMinimized = false;
    public bool isMaximized = false;
    private Rect preMaximizeRect;
    private bool isResizing = false;
    private Vector2 resizeStartPos;
    private Vector2 resizeStartSize;
    public int currentTab = 0; // 0=MÁQUINAS, 1=CONTROL CENTER (3 MÁQUINAS), 2=PAGO, 3=MDB, 4=GROG EDGE, 5=TRANSACCIÓN, 6=TELEMETRÍA, 7=AI
    private Vector2 scrollPos = Vector2.zero;

    [Header("Pantallas Físicas 3D de QR (Una por Máquina)")]
    public Renderer vendingQrRenderer;
    public Renderer coolerQrRenderer;
    public Renderer coffeeQrRenderer;
    public Texture2D qrIdleTexture;

    [Header("Conectividad Backend / GROG")]
    [Tooltip("URL del Orquestador de Transacciones")]
    public string orchestratorUrl = "http://127.0.0.1:8010";
    [Tooltip("URL del Vending Service de GROG")]
    public string vendingUrl = "http://127.0.0.1:8040";
    [Tooltip("URL pública de la pasarela de pago SimuPay")]
    public string cloudflareGatewayUrl = "https://passivism-sighing-condense.ngrok-free.dev";
    public SerialBridge serialBridge;

    [Header("Modo Instalador / Vinculación Segura")]
    public bool showInstallerModal = false;
    public string pairingPin = "";
    public string pairingToken = "";
    public float pairingSecondsLeft = 0f;
    public bool isPairingRequesting = false;
    public bool isRebooting = false;
    public bool isMachineClaimed = false;
    public string claimedOwnerEmail = "";
    private Coroutine pollPairingCoroutine = null;
    private Texture2D pairingQrTexture = null;

    [Header("Ventana Emergente de Pago GROG")]
    public bool showPaymentModal = false;
    public Rect paymentModalRect = new Rect(0, 0, 360, 430);
    public Texture2D activeQrTexture = null;

    [Header("Telemetría en Vivo")]
    public float telemetryLatency = 34f;
    public string vmcStatus = "ONLINE (9600 Bd)";
    public string mqttStatus = "CONNECTED (WSS/TLS)";
    public string edgeStatus = "ONLINE (ESP32 Core)";
    public string adapterStatus = "MDB LEVEL 3 (ACTIVE)";

    // Control de cámara
    private Vector3 camTargetPos;
    private Vector3 camTargetLookAt;
    private List<Transform> activeSpringTransforms = new List<Transform>();
    private List<GameObject> activeSnackProducts = new List<GameObject>();
    private List<GameObject> dispensedTrayObjects = new List<GameObject>();
    public bool isPhysicalCoinProcessing = false;
    private Texture2D defaultIdleTexture;

    private void Awake()
    {
#if UNITY_WEBGL
        if (string.IsNullOrEmpty(cloudflareGatewayUrl) || cloudflareGatewayUrl.Contains("trycloudflare.com"))
        {
            cloudflareGatewayUrl = "https://passivism-sighing-condense.ngrok-free.dev";
        }
        string baseGw = cloudflareGatewayUrl.TrimEnd('/');
        orchestratorUrl = $"{baseGw}/p/8010";
        vendingUrl = $"{baseGw}/p/8040";
#else
        if (string.IsNullOrEmpty(orchestratorUrl) || orchestratorUrl.Contains("trycloudflare.com"))
        {
            orchestratorUrl = "http://127.0.0.1:8010";
        }
        if (string.IsNullOrEmpty(vendingUrl) || vendingUrl.Contains("trycloudflare.com"))
        {
            vendingUrl = "http://127.0.0.1:8040";
        }
        if (string.IsNullOrEmpty(cloudflareGatewayUrl) || cloudflareGatewayUrl.Contains("trycloudflare.com"))
        {
            cloudflareGatewayUrl = "https://passivism-sighing-condense.ngrok-free.dev";
        }
#endif
        InitializeCatalog();
    }

    private void Start()
    {
        if (mainCamera == null) mainCamera = Camera.main;

        if (cameraPresets != null && cameraPresets.Length > 0)
        {
            camTargetPos = cameraPresets[0].position;
            camTargetLookAt = cameraPresets[0].lookAt;
            if (mainCamera != null)
            {
                mainCamera.transform.position = camTargetPos;
                mainCamera.transform.LookAt(camTargetLookAt);
            }
        }

        paymentModalRect.x = (Screen.width - paymentModalRect.width) / 2f;
        paymentModalRect.y = (Screen.height - paymentModalRect.height) / 2f;

        CreateDefaultIdleTexture();
        ResetAll3DQrDisplays();
        RebuildParametricShelves();
        SetProofOfServiceState("IDLE");
    }

    private void CreateDefaultIdleTexture()
    {
        if (defaultIdleTexture != null) return;
        defaultIdleTexture = new Texture2D(128, 128, TextureFormat.RGBA32, false);
        Color bgColor = new Color(0.04f, 0.08f, 0.14f, 1f);
        Color frameColor = new Color(0.12f, 0.65f, 0.95f, 1f);
        Color innerBox = new Color(0.08f, 0.16f, 0.28f, 1f);

        for (int y = 0; y < 128; y++)
        {
            for (int x = 0; x < 128; x++)
            {
                bool isBorder = (x < 5 || x > 122 || y < 5 || y > 122);
                bool isInnerBorder = ((x >= 20 && x <= 107) && (y == 20 || y == 107)) ||
                                     ((y >= 20 && y <= 107) && (x == 20 || x == 107));
                bool isCenterArea = (x >= 21 && x <= 106 && y >= 21 && y <= 106);

                if (isBorder || isInnerBorder)
                    defaultIdleTexture.SetPixel(x, y, frameColor);
                else if (isCenterArea)
                    defaultIdleTexture.SetPixel(x, y, innerBox);
                else
                    defaultIdleTexture.SetPixel(x, y, bgColor);
            }
        }
        defaultIdleTexture.Apply();
    }

    public void UpdateMachine3DQrDisplays(Texture2D qrTexture, string targetMachineId)
    {
        ResetAll3DQrDisplays();
        if (qrTexture == null) return;

        if (targetMachineId == "VENDING-01" && vendingQrRenderer != null)
        {
            vendingQrRenderer.material.mainTexture = qrTexture;
        }
        else if (targetMachineId == "COOLER-01" && coolerQrRenderer != null)
        {
            coolerQrRenderer.material.mainTexture = qrTexture;
        }
        else if (targetMachineId == "COFFEE-01" && coffeeQrRenderer != null)
        {
            coffeeQrRenderer.material.mainTexture = qrTexture;
        }
    }

    public void ResetAll3DQrDisplays()
    {
        Texture2D idle = qrIdleTexture != null ? qrIdleTexture : defaultIdleTexture;
        if (vendingQrRenderer != null && idle != null) vendingQrRenderer.material.mainTexture = idle;
        if (coolerQrRenderer != null && idle != null) coolerQrRenderer.material.mainTexture = idle;
        if (coffeeQrRenderer != null && idle != null) coffeeQrRenderer.material.mainTexture = idle;
    }

    public void SelectProductByMachineAndSlot(string machineId, int slot, string itemId = "")
    {
        SwitchActiveMachine(machineId);
        List<MachineItem> list = null;
        if (machineId == "VENDING-01") list = vendingSnackItems;
        else if (machineId == "COOLER-01") list = coldDrinkItems;
        else if (machineId == "COFFEE-01") list = coffeeItems;

        if (list != null)
        {
            MachineItem item = null;
            if (!string.IsNullOrEmpty(itemId))
            {
                item = list.Find(x => x.id == itemId);
            }
            if (item == null && slot >= 1 && slot <= list.Count)
            {
                item = list[slot - 1];
            }
            if (item != null)
            {
                SelectProductToBuy(item);
            }
        }
    }

    private void InitializeCatalog()
    {
        // 1. MÁQUINA 1: EXPENDEDORA DE SNACKS (VENDING-01) - Basado en foto 4
        vendingSnackItems.Clear();
        vendingSnackItems.Add(new MachineItem { id = "SNK-01", name = "Papas Sabores / Lays", category = "SNACK", price = 6.00f, stock = 8, maxStock = 12, color = new Color(1.0f, 0.75f, 0.1f), machineId = "VENDING-01", slotNumber = 1 });
        vendingSnackItems.Add(new MachineItem { id = "SNK-02", name = "Galletas Oreo Doble", category = "SNACK", price = 5.50f, stock = 10, maxStock = 12, color = new Color(0.2f, 0.5f, 0.9f), machineId = "VENDING-01", slotNumber = 2 });
        vendingSnackItems.Add(new MachineItem { id = "SNK-03", name = "Club Social Clásica", category = "SNACK", price = 4.00f, stock = 12, maxStock = 15, color = new Color(0.1f, 0.4f, 0.85f), machineId = "VENDING-01", slotNumber = 3 });
        vendingSnackItems.Add(new MachineItem { id = "SNK-04", name = "Galletas Field Vainilla", category = "SNACK", price = 4.50f, stock = 9, maxStock = 12, color = new Color(0.9f, 0.3f, 0.3f), machineId = "VENDING-01", slotNumber = 4 });
        vendingSnackItems.Add(new MachineItem { id = "SNK-05", name = "Chocman Chocolate", category = "SNACK", price = 4.00f, stock = 7, maxStock = 10, color = new Color(0.6f, 0.3f, 0.1f), machineId = "VENDING-01", slotNumber = 5 });
        vendingSnackItems.Add(new MachineItem { id = "SNK-06", name = "Snickers Barra", category = "SNACK", price = 6.50f, stock = 9, maxStock = 12, color = new Color(0.5f, 0.25f, 0.1f), machineId = "VENDING-01", slotNumber = 6 });
        vendingSnackItems.Add(new MachineItem { id = "SNK-07", name = "Ronditas Vainilla", category = "SNACK", price = 3.50f, stock = 11, maxStock = 12, color = new Color(0.85f, 0.8f, 0.2f), machineId = "VENDING-01", slotNumber = 7 });
        vendingSnackItems.Add(new MachineItem { id = "SNK-08", name = "Gomitas Frutales", category = "SNACK", price = 4.50f, stock = 6, maxStock = 10, color = new Color(0.9f, 0.2f, 0.8f), machineId = "VENDING-01", slotNumber = 8 });
        vendingSnackItems.Add(new MachineItem { id = "SNK-09", name = "Maní Salado Crocante", category = "SNACK", price = 3.00f, stock = 12, maxStock = 15, color = new Color(0.9f, 0.6f, 0.3f), machineId = "VENDING-01", slotNumber = 9 });

        // 2. MÁQUINA 2: BEBIDAS REFRIGERADAS (COOLER-01) - Basado en botellero Powerade foto 5
        coldDrinkItems.Clear();
        coldDrinkItems.Add(new MachineItem { id = "PWR-01", name = "Powerade Mountain Blast (Azul)", category = "DRINK", price = 8.00f, stock = 8, maxStock = 12, color = new Color(0.1f, 0.6f, 0.95f), machineId = "COOLER-01", slotNumber = 1 });
        coldDrinkItems.Add(new MachineItem { id = "PWR-02", name = "Powerade Ion4 Manzana (Verde)", category = "DRINK", price = 8.00f, stock = 7, maxStock = 12, color = new Color(0.2f, 0.85f, 0.25f), machineId = "COOLER-01", slotNumber = 2 });
        coldDrinkItems.Add(new MachineItem { id = "COLA-03", name = "Coca-Cola Original 500ml", category = "DRINK", price = 8.00f, stock = 10, maxStock = 12, color = new Color(0.9f, 0.1f, 0.1f), machineId = "COOLER-01", slotNumber = 3 });
        coldDrinkItems.Add(new MachineItem { id = "SPRITE-04", name = "Sprite Lima Limón Zero", category = "DRINK", price = 7.00f, stock = 9, maxStock = 12, color = new Color(0.1f, 0.8f, 0.3f), machineId = "COOLER-01", slotNumber = 4 });
        coldDrinkItems.Add(new MachineItem { id = "FANTA-05", name = "Fanta Naranja 500ml", category = "DRINK", price = 7.00f, stock = 8, maxStock = 12, color = new Color(1.0f, 0.55f, 0.1f), machineId = "COOLER-01", slotNumber = 5 });
        coldDrinkItems.Add(new MachineItem { id = "WATER-06", name = "Agua Mineral Vital 600ml", category = "DRINK", price = 5.00f, stock = 14, maxStock = 15, color = new Color(0.2f, 0.8f, 1.0f), machineId = "COOLER-01", slotNumber = 6 });

        // 3. MÁQUINA 3: CAFÉ ESPECIALIZADO (COFFEE-01) - Basado en HotBox Café / Concerto NECTA fotos 1, 2, 3, 4
        coffeeItems.Clear();
        coffeeItems.Add(new MachineItem { id = "HOT-01", name = "Café Avellanas", category = "COFFEE", price = 6.00f, stock = 20, maxStock = 25, color = new Color(0.55f, 0.35f, 0.15f), machineId = "COFFEE-01", slotNumber = 1 });
        coffeeItems.Add(new MachineItem { id = "HOT-02", name = "Cappuccino Avellanas", category = "COFFEE", price = 6.00f, stock = 18, maxStock = 25, color = new Color(0.85f, 0.65f, 0.40f), machineId = "COFFEE-01", slotNumber = 2 });
        coffeeItems.Add(new MachineItem { id = "HOT-03", name = "Chocolate Suizo", category = "COFFEE", price = 6.00f, stock = 22, maxStock = 25, color = new Color(0.40f, 0.20f, 0.10f), machineId = "COFFEE-01", slotNumber = 3 });
        coffeeItems.Add(new MachineItem { id = "HOT-04", name = "Espresso Italiano", category = "COFFEE", price = 5.00f, stock = 25, maxStock = 25, color = new Color(0.30f, 0.15f, 0.05f), machineId = "COFFEE-01", slotNumber = 4 });
        coffeeItems.Add(new MachineItem { id = "HOT-05", name = "Café Americano", category = "COFFEE", price = 5.00f, stock = 24, maxStock = 25, color = new Color(0.35f, 0.18f, 0.08f), machineId = "COFFEE-01", slotNumber = 5 });
        coffeeItems.Add(new MachineItem { id = "HOT-06", name = "Café con Leche", category = "COFFEE", price = 6.00f, stock = 19, maxStock = 25, color = new Color(0.80f, 0.65f, 0.45f), machineId = "COFFEE-01", slotNumber = 6 });
        coffeeItems.Add(new MachineItem { id = "HOT-07", name = "Mocaccino", category = "COFFEE", price = 6.00f, stock = 16, maxStock = 25, color = new Color(0.50f, 0.28f, 0.15f), machineId = "COFFEE-01", slotNumber = 7 });
        coffeeItems.Add(new MachineItem { id = "HOT-08", name = "Vainilla Francesa", category = "COFFEE", price = 6.00f, stock = 15, maxStock = 25, color = new Color(0.92f, 0.85f, 0.60f), machineId = "COFFEE-01", slotNumber = 8 });
    }

    private void Update()
    {
        // 1. Suavizado de Cámara
        if (mainCamera != null)
        {
            mainCamera.transform.position = Vector3.Lerp(mainCamera.transform.position, camTargetPos, Time.deltaTime * 3.5f);
            Vector3 currentLookAt = mainCamera.transform.position + mainCamera.transform.forward * 5f;
            Vector3 smoothLookAt = Vector3.Lerp(currentLookAt, camTargetLookAt, Time.deltaTime * 4.0f);
            mainCamera.transform.LookAt(smoothLookAt);
        }

        // 2. Navegación libre con mouse
        if (Input.GetMouseButton(1) && mainCamera != null)
        {
            float rotX = Input.GetAxis("Mouse X") * 3.0f;
            float rotY = -Input.GetAxis("Mouse Y") * 3.0f;
            mainCamera.transform.RotateAround(camTargetLookAt, Vector3.up, rotX);
            mainCamera.transform.RotateAround(camTargetLookAt, mainCamera.transform.right, rotY);
            camTargetPos = mainCamera.transform.position;
        }

        float scroll = Input.GetAxis("Mouse ScrollWheel");
        if (Mathf.Abs(scroll) > 0.01f && mainCamera != null)
        {
            camTargetPos += mainCamera.transform.forward * scroll * 3.5f;
        }

        // 3. Puerta del refrigerador
        if (coolerDoorTransform != null)
        {
            float targetAngle = isCoolerDoorOpen ? -100f : 0f;
            Quaternion targetRot = Quaternion.Euler(0f, targetAngle, 0f);
            coolerDoorTransform.localRotation = Quaternion.Slerp(coolerDoorTransform.localRotation, targetRot, Time.deltaTime * 4.0f);
        }

        // 4. Actualización de displays
        if (coolerTempText != null)
        {
            float tempFluctuation = Mathf.Sin(Time.time * 0.8f) * 0.12f;
            float currentTemp = targetCoolerTemp + (isCoolerDoorOpen ? 2.3f : 0f) + tempFluctuation;
            coolerTempText.text = $"{currentTemp:F1} °C\n[REFRIGERADO]";
        }

        if (distanceGaugeText != null)
        {
            distanceGaugeText.text = $"{currentMeasuredDistance:F1} cm\n[HC-SR04]";
        }

        // 5. Atajos de teclado (1-7 cámaras, H HUD, I/M Modo Instalador)
        if (Input.GetKeyDown(KeyCode.H))
        {
            showUI = !showUI;
        }

        if (Input.GetKeyDown(KeyCode.M) || Input.GetKeyDown(KeyCode.I))
        {
            ToggleInstallerMode();
        }

        if (showInstallerModal && pairingSecondsLeft > 0f)
        {
            pairingSecondsLeft -= Time.deltaTime;
            if (pairingSecondsLeft <= 0f) pairingSecondsLeft = 0f;
        }

        for (int i = 0; i < cameraPresets.Length && i < 7; i++)
        {
            if (Input.GetKeyDown(KeyCode.Alpha1 + i) || Input.GetKeyDown(KeyCode.Keypad1 + i))
            {
                SelectCameraView(i);
            }
        }
    }

    public void SelectCameraView(int index)
    {
        if (cameraPresets == null || index < 0 || index >= cameraPresets.Length) return;
        currentViewIndex = index;
        camTargetPos = cameraPresets[index].position;
        camTargetLookAt = cameraPresets[index].lookAt;
        currentStepNarrator = cameraPresets[index].description;
    }

    public void SwitchActiveMachine(string machineId)
    {
        activeMachineId = machineId;
        if (machineId == "VENDING-01")
        {
            activeMachineType = MachineType.VENDING_SNACKS;
            currentStepNarrator = "Máquina Activa: VENDING-01 (Expendedora tradicional de snacks y productos sólidos).";
            SelectCameraView(1);
        }
        else if (machineId == "COOLER-01")
        {
            activeMachineType = MachineType.COLD_BEVERAGES;
            currentStepNarrator = "Máquina Activa: COOLER-01 (Gabinete refrigerado independiente de bebidas a 4.2 °C).";
            SelectCameraView(2);
        }
        else if (machineId == "COFFEE-01")
        {
            activeMachineType = MachineType.COFFEE;
            currentStepNarrator = "Máquina Activa: COFFEE-01 (Máquina automática de café y bebidas calientes a 92 °C).";
            SelectCameraView(3);
        }
    }

    public void ToggleCoolerDoor()
    {
        isCoolerDoorOpen = !isCoolerDoorOpen;
        currentStepNarrator = isCoolerDoorOpen
            ? "Puerta del Refrigerador Abierta: Acceso a estantes iluminados con latas y botellas."
            : "Puerta del Refrigerador Cerrada: Aislamiento térmico presurizado a 4.2 °C.";
    }

    #region Reconstrucción de Snacks Paramétricos
    public void RebuildParametricShelves()
    {
        if (snackShelvesParent == null) return;

        for (int i = snackShelvesParent.childCount - 1; i >= 0; i--)
        {
            Destroy(snackShelvesParent.GetChild(i).gameObject);
        }
        activeSpringTransforms.Clear();
        activeSnackProducts.Clear();

        float totalWidth = 0.82f; // Ajustado a 0.82f para que los resortes queden 100% contenidos dentro de la bandeja metálica (1.18m)
        float startX = -totalWidth / 2f;
        float spacingX = totalWidth / Mathf.Max(1, columnsCount - 1);
        float[] rowY = new float[] { 2.52f, 2.02f, 1.52f }; // Apoyados justo encima de cada balda metálica

        int productNumber = 1;
        Color[] snackColors = new Color[]
        {
            new Color(0.9f, 0.2f, 0.2f),
            new Color(0.2f, 0.6f, 1.0f),
            new Color(0.2f, 0.8f, 0.3f),
            new Color(1.0f, 0.65f, 0.1f),
            new Color(0.7f, 0.2f, 0.9f),
            new Color(1.0f, 0.9f, 0.2f),
            new Color(0.1f, 0.8f, 0.8f),
            new Color(0.9f, 0.4f, 0.7f),
            new Color(0.8f, 0.5f, 0.2f)
        };

        for (int r = 0; r < rowY.Length; r++)
        {
            for (int c = 0; c < columnsCount; c++)
            {
                float posX = startX + (c * spacingX);
                float posY = rowY[r];
                // Posición Z retranqueada hacia el fondo de la bandeja (0.16f) para que el resorte no sobresalga del vidrio frontal
                Vector3 springLocalPos = new Vector3(posX, posY, 0.16f);

                GameObject springObj = new GameObject($"Spring_R{r + 1}_C{c + 1}");
                springObj.transform.SetParent(snackShelvesParent, false);
                springObj.transform.localPosition = springLocalPos;
                // Escala contenida y compacta: radio y longitud reducidos para evitar desbordes
                springObj.transform.localScale = new Vector3(0.70f, 0.70f, 0.58f);

                if (springMesh != null)
                {
                    MeshFilter mf = springObj.AddComponent<MeshFilter>();
                    mf.sharedMesh = springMesh;
                    MeshRenderer mr = springObj.AddComponent<MeshRenderer>();
                    mr.sharedMaterial = matSpring;
                }

                activeSpringTransforms.Add(springObj.transform);

                GameObject snackObj = GameObject.CreatePrimitive(PrimitiveType.Cube);
                snackObj.name = $"Snack_Item_{productNumber}";
                snackObj.transform.SetParent(snackShelvesParent, false);
                snackObj.transform.localPosition = springLocalPos + new Vector3(0f, 0.04f, -0.12f);
                snackObj.transform.localScale = new Vector3(0.12f, 0.12f, 0.12f);

                Renderer rend = snackObj.GetComponent<Renderer>();
                if (rend != null)
                {
                    rend.material.color = snackColors[(productNumber - 1) % snackColors.Length];
                }

                Collider col = snackObj.GetComponent<Collider>();
                if (col != null) col.enabled = false;

                activeSnackProducts.Add(snackObj);
                productNumber++;
            }
        }
    }
    #endregion

    #region Selección de Producto & Flujo de Pago
    public void SelectProductToBuy(MachineItem item)
    {
        if (currentTxState != TransactionState.IDLE && currentTxState != TransactionState.COMPLETED && currentTxState != TransactionState.REFUND)
        {
            Debug.LogWarning("[GROG] Máquina ocupada con otra transacción.");
            return;
        }

        if (item.stock <= 0)
        {
            transactionStatusMessage = $"PRODUCTO AGOTADO: {item.name}";
            currentStepNarrator = $"El producto {item.name} no cuenta con stock disponible en {item.machineId}.";
            return;
        }

        selectedItem = item;
        selectedItem.itemState = "RESERVED";
        currentTxState = TransactionState.PRODUCT_SELECTED;
        currentTxId = $"GROG-{item.machineId.Substring(0, 3)}-{UnityEngine.Random.Range(100000, 999999)}";

        transactionStatusMessage = $"SELECCIONADO: {item.name} — Bs {item.price:F2} ({item.machineId})";
        currentStepNarrator = $"Paso 1: Producto seleccionado '{item.name}'. Creando orden transaccional en GROG Cloud...";

        StartCoroutine(PreparePaymentOrderWorkflow());
    }

    [System.Serializable]
    private class ApiInitResponse { public string id; public string tx_id; }
    [System.Serializable]
    private class ApiQrResponse { public string qr_image; }

    private IEnumerator PreparePaymentOrderWorkflow()
    {
        currentTxState = TransactionState.PAYMENT_PENDING;
        transactionStatusMessage = $"CREANDO ORDEN EN GROG CLOUD ({orchestratorUrl})...";
        currentStepNarrator = $"Paso 1: Contactando Transaction Orchestrator por HTTPS...";

        // 1. Intentar registrar la transacción real en el Orchestrator de Cloudflare
        string initUrl = orchestratorUrl.TrimEnd('/') + "/api/v1/transactions/init";
        string sku = selectedItem.id;
        string initPayload = $"{{\"machine_id\":\"{selectedItem.machineId}\",\"product_id\":\"{sku}\",\"amount\":{selectedItem.price.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)},\"payment_method\":\"QR\"}}";

        string remoteTxId = "";
        using (UnityWebRequest initReq = new UnityWebRequest(initUrl, "POST"))
        {
            byte[] bodyRaw = Encoding.UTF8.GetBytes(initPayload);
            initReq.uploadHandler = new UploadHandlerRaw(bodyRaw);
            initReq.downloadHandler = new DownloadHandlerBuffer();
            initReq.SetRequestHeader("Content-Type", "application/json");
            initReq.SetRequestHeader("ngrok-skip-browser-warning", "1");
            initReq.timeout = 5;

            yield return initReq.SendWebRequest();

            if (initReq.result == UnityWebRequest.Result.Success)
            {
                string json = initReq.downloadHandler.text;
                ApiInitResponse res = JsonUtility.FromJson<ApiInitResponse>(json);
                remoteTxId = !string.IsNullOrEmpty(res.tx_id) ? res.tx_id : res.id;
                Debug.Log($"[GROG Cloud] Transacción registrada en Orchestrator: {remoteTxId}");
            }
            else
            {
                Debug.LogWarning($"[GROG Cloud] Modo híbrido local/edge (Backend no respondió en 5s: {initReq.error})");
            }
        }

        if (!string.IsNullOrEmpty(remoteTxId))
        {
            currentTxId = remoteTxId;

            // 2. Solicitar QR real al backend
            string qrUrl = $"{orchestratorUrl.TrimEnd('/')}/api/v1/transactions/{currentTxId}/generate-qr";
            using (UnityWebRequest qrReq = new UnityWebRequest(qrUrl, "POST"))
            {
                byte[] emptyBody = Encoding.UTF8.GetBytes("{}");
                qrReq.uploadHandler = new UploadHandlerRaw(emptyBody);
                qrReq.downloadHandler = new DownloadHandlerBuffer();
                qrReq.SetRequestHeader("Content-Type", "application/json");
                qrReq.SetRequestHeader("ngrok-skip-browser-warning", "1");
                qrReq.timeout = 5;

                yield return qrReq.SendWebRequest();

                if (qrReq.result == UnityWebRequest.Result.Success)
                {
                    ApiQrResponse qres = JsonUtility.FromJson<ApiQrResponse>(qrReq.downloadHandler.text);
                    if (!string.IsNullOrEmpty(qres.qr_image))
                    {
                        try
                        {
                            string b64 = qres.qr_image.Contains(",") ? qres.qr_image.Substring(qres.qr_image.IndexOf(",") + 1) : qres.qr_image;
                            byte[] imgBytes = Convert.FromBase64String(b64);
                            Texture2D remoteTex = new Texture2D(256, 256, TextureFormat.RGBA32, false);
                            remoteTex.filterMode = FilterMode.Point;
                            remoteTex.LoadImage(imgBytes);
                            activeQrTexture = remoteTex;
                        }
                        catch { activeQrTexture = null; }
                    }
                }
            }
        }

        // Si el backend no devolvió imagen o estamos offline, generar QR dinámico matemáticamente
        if (activeQrTexture == null)
        {
            activeQrTexture = GenerateProceduralQrTexture(selectedItem.id, selectedItem.price);
        }

        showPaymentModal = true;
        SetProofOfServiceState("IDLE");

        // Proyectar el código QR en la pantalla 3D física de la máquina que realiza la venta
        UpdateMachine3DQrDisplays(activeQrTexture, selectedItem.machineId);

        if (pollPaymentStatusCoroutine != null) StopCoroutine(pollPaymentStatusCoroutine);
        pollPaymentStatusCoroutine = StartCoroutine(PollPaymentStatusWorker(currentTxId));

        transactionStatusMessage = $"PAGO PENDIENTE (Bs {selectedItem.price:F2}) — QR GENERADO EN {selectedItem.machineId}";
        currentStepNarrator = $"Paso 2: Transacción {currentTxId} creada. Escanee el QR en la pantalla de la máquina o en el panel para autorizar.";
    }

    [System.Serializable]
    private class TxPollResponse { public string id; public string tx_id; public string state; }

    private Coroutine pollPaymentStatusCoroutine;

    private IEnumerator PollPaymentStatusWorker(string txId)
    {
        string statusUrl = $"{orchestratorUrl.TrimEnd('/')}/api/v1/transactions/{txId}";
        float elapsed = 0f;
        float timeout = 120f;

        while (showPaymentModal && currentTxState == TransactionState.PAYMENT_PENDING && elapsed < timeout)
        {
            yield return new WaitForSeconds(1.5f);
            elapsed += 1.5f;

            using (UnityWebRequest pollReq = UnityWebRequest.Get(statusUrl))
            {
                pollReq.SetRequestHeader("ngrok-skip-browser-warning", "1");
                yield return pollReq.SendWebRequest();

                if (pollReq.result == UnityWebRequest.Result.Success)
                {
                    TxPollResponse status = JsonUtility.FromJson<TxPollResponse>(pollReq.downloadHandler.text);
                    if (status != null && !string.IsNullOrEmpty(status.state))
                    {
                        if (status.state == "PAID_PENDING_DISPENSE" || status.state == "PAID")
                        {
                            Debug.Log($"[GROG Cloud] ¡Pago confirmado desde App Móvil / Web para TX {txId}! Dispensando...");
                            AuthorizePaymentNow();
                            yield break;
                        }
                        else if (status.state == "CANCELLED" || status.state == "REFUNDED")
                        {
                            CancelCurrentTransaction($"ESTADO: {status.state}");
                            yield break;
                        }
                    }
                }
            }
        }
    }

    public void AuthorizePaymentNow()
    {
        if (pollPaymentStatusCoroutine != null)
        {
            StopCoroutine(pollPaymentStatusCoroutine);
            pollPaymentStatusCoroutine = null;
        }
        if (currentTxState != TransactionState.PAYMENT_PENDING) return;
        StartCoroutine(ProcessAuthorizedTransaction());
    }

    public void CancelCurrentTransaction(string reason = "CANCELADO POR USUARIO")
    {
        if (pollPaymentStatusCoroutine != null)
        {
            StopCoroutine(pollPaymentStatusCoroutine);
            pollPaymentStatusCoroutine = null;
        }
        if (selectedItem != null)
        {
            selectedItem.itemState = "AVAILABLE";
        }
        ResetAll3DQrDisplays();
        showPaymentModal = false;
        currentTxState = TransactionState.IDLE;
        transactionStatusMessage = reason;
        currentStepNarrator = "Transacción cancelada. Fondos liberados y máquina en reposo.";
    }

    private IEnumerator ProcessAuthorizedTransaction()
    {
        currentTxState = TransactionState.PAYMENT_AUTHORIZED;
        transactionStatusMessage = "PAGO AUTORIZADO POR GROG PAYMENT SERVICE";
        currentStepNarrator = "Paso 3: Pago digital autorizado por la pasarela Cloud. Enviando instrucción al GROG Universal Edge...";
        yield return new WaitForSeconds(1.2f);

        showPaymentModal = false;
        currentTxState = TransactionState.DISPENSE_PENDING;
        transactionStatusMessage = "ORDEN ENVIADA: GROG EDGE -> MACHINE ADAPTER -> CONTROLADOR";
        currentStepNarrator = "Paso 4: El Edge Gateway traduce el comando según la interfaz de la máquina (MDB / Relé / Pulso).";
        yield return new WaitForSeconds(1.0f);

        if (selectedItem.machineId == "COFFEE-01" || selectedItem.category == "COFFEE")
        {
            yield return StartCoroutine(DispenseCoffeeWorkflow());
        }
        else if (selectedItem.machineId == "COOLER-01" || selectedItem.category == "DRINK")
        {
            yield return StartCoroutine(DispenseCoolerDrinkWorkflow());
        }
        else
        {
            yield return StartCoroutine(DispenseVendingSnackWorkflow());
        }
    }
    #endregion

    #region Rutinas de Dispensado y Proof of Service
    private IEnumerator DispenseVendingSnackWorkflow()
    {
        currentTxState = TransactionState.DISPENSING;
        transactionStatusMessage = $"DISPENSANDO SNACK: {selectedItem.name}...";
        currentStepNarrator = $"Paso 5: VMC acciona motor de ranura #{selectedItem.slotNumber}. Giro helicoidal 360° en VENDING-01.";

        int slotIdx = Mathf.Clamp(selectedItem.slotNumber - 1, 0, Mathf.Max(0, activeSpringTransforms.Count - 1));
        Transform activeSpiral = (slotIdx < activeSpringTransforms.Count) ? activeSpringTransforms[slotIdx] : null;
        GameObject activeSnack = (slotIdx < activeSnackProducts.Count) ? activeSnackProducts[slotIdx] : null;

        if (activeSpiral != null)
        {
            yield return StartCoroutine(AnimateSpiralAndPushSnack(activeSpiral, activeSnack));
        }
        else
        {
            yield return new WaitForSeconds(0.9f);
        }

        currentTxState = TransactionState.DELIVERY_VERIFYING;
        transactionStatusMessage = "VERIFICANDO ENTREGA: SENSOR HC-SR04...";
        currentStepNarrator = "Paso 6: El snack cae en la tolva receptora por gravedad física. Sensor HC-SR04 detecta variación...";

        // Snack que cae con Rigidbody y gravedad
        GameObject fallingObj = null;
        if (activeSnack != null)
        {
            fallingObj = activeSnack;
            activeSnackProducts[slotIdx] = null; // Se retira de la balda para reflejar venta real
            fallingObj.transform.SetParent(null, true);
        }
        else
        {
            fallingObj = GameObject.CreatePrimitive(PrimitiveType.Cube);
            fallingObj.transform.localScale = new Vector3(0.14f, 0.14f, 0.14f);
            Vector3 spawnP = (activeSpiral != null) ? activeSpiral.position : new Vector3(-4.05f, 2.02f, -0.15f);
            fallingObj.transform.position = spawnP + new Vector3(0f, 0.05f, -0.22f);
            Renderer rend = fallingObj.GetComponent<Renderer>();
            if (rend != null) rend.material.color = selectedItem.color;
        }

        fallingObj.name = $"Dropped_{selectedItem.name}";
        Collider col = fallingObj.GetComponent<Collider>();
        if (col == null) col = fallingObj.AddComponent<BoxCollider>();
        col.enabled = true;

        Rigidbody rb = fallingObj.GetComponent<Rigidbody>();
        if (rb == null) rb = fallingObj.AddComponent<Rigidbody>();
        rb.mass = 0.45f;
        rb.useGravity = true;
        rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
        // Impulso hacia adelante para salvar el borde del estante y caer directo a la tolva
        rb.linearVelocity = new Vector3(UnityEngine.Random.Range(-0.04f, 0.04f), -0.6f, -0.25f);
        rb.angularVelocity = UnityEngine.Random.insideUnitSphere * 3.5f;

        dispensedTrayObjects.Add(fallingObj);
        if (dispensedTrayObjects.Count > 6)
        {
            if (dispensedTrayObjects[0] != null) Destroy(dispensedTrayObjects[0]);
            dispensedTrayObjects.RemoveAt(0);
        }

        float dropTime = 0f;
        while (dropTime < 0.9f)
        {
            dropTime += Time.deltaTime;
            currentMeasuredDistance = Mathf.Lerp(32.5f, 11.4f, dropTime / 0.9f);
            yield return null;
        }
        currentMeasuredDistance = 11.4f;
        yield return new WaitForSeconds(0.5f);

        currentTxState = TransactionState.PROOF_OF_SERVICE;
        SetProofOfServiceState("VERIFIED");
        transactionStatusMessage = "PROOF OF SERVICE VERIFIED (Sensor HC-SR04 + Telemetría Motor)";
        currentStepNarrator = "Paso 7: ¡Proof of Service Confirmado! Producto presente en tolva receptora.";
        yield return new WaitForSeconds(1.8f);

        currentTxState = TransactionState.CAPTURE;
        selectedItem.stock = Mathf.Max(0, selectedItem.stock - 1);
        selectedItem.itemState = "AVAILABLE";
        transactionStatusMessage = $"CAPTURA COMPLETADA: FONDOS LIQUIDADOS (Stock: {selectedItem.stock})";
        currentStepNarrator = "Paso 8: Fondos capturados exitosamente. Inventario sincronizado en Digital Twin en tiempo real.";

        if (!string.IsNullOrEmpty(currentTxId))
        {
            StartCoroutine(SendDispenseResultToBackend(currentTxId, true));
        }

        yield return new WaitForSeconds(1.6f);

        ResetAll3DQrDisplays();
        currentTxState = TransactionState.COMPLETED;
        transactionStatusMessage = "SNACK ENTREGADO CON ÉXITO — DISPONIBLE EN BANDEJA";
        currentStepNarrator = "Transacción completada en VENDING-01. El producto reposa en la tolva receptora.";
    }

    private IEnumerator DispenseCoolerDrinkWorkflow()
    {
        currentTxState = TransactionState.DISPENSING;
        transactionStatusMessage = $"LIBERANDO BEBIDA: {selectedItem.name} (4.2 °C)...";
        currentStepNarrator = "Paso 5: Actuador de compuerta activado en COOLER-01. Liberación por gravedad de lata/botella.";
        yield return new WaitForSeconds(1.6f);

        currentTxState = TransactionState.DELIVERY_VERIFYING;
        transactionStatusMessage = "VERIFICANDO ENTREGA: SENSOR ÓPTICO DE SALIDA...";
        currentStepNarrator = "Paso 6: Sensor de cortina óptica confirma paso de botella hacia la rampa receptora refrigerada.";
        yield return new WaitForSeconds(1.2f);

        currentTxState = TransactionState.PROOF_OF_SERVICE;
        SetProofOfServiceState("VERIFIED");
        transactionStatusMessage = "PROOF OF SERVICE VERIFIED (Sensor Óptico + Telemetría Refrigerador)";
        currentStepNarrator = "Paso 7: ¡Proof of Service Confirmado! Bebida refrigerada entregada.";
        yield return new WaitForSeconds(1.8f);

        currentTxState = TransactionState.CAPTURE;
        selectedItem.stock = Mathf.Max(0, selectedItem.stock - 1);
        selectedItem.itemState = "AVAILABLE";
        transactionStatusMessage = $"CAPTURA COMPLETADA (Stock: {selectedItem.stock})";
        currentStepNarrator = "Paso 8: Fondos liquidados. Inventario actualizado en COOLER-01.";

        if (!string.IsNullOrEmpty(currentTxId))
        {
            StartCoroutine(SendDispenseResultToBackend(currentTxId, true));
        }

        yield return new WaitForSeconds(1.6f);

        ResetAll3DQrDisplays();
        currentTxState = TransactionState.COMPLETED;
        transactionStatusMessage = "BEBIDA FRÍA DISPENSADA CON ÉXITO";
        currentStepNarrator = "Demostración de refrigerador completada con éxito.";
    }

    private IEnumerator DispenseCoffeeWorkflow()
    {
        currentTxState = TransactionState.DISPENSING;
        transactionStatusMessage = $"PREPARANDO: {selectedItem.name} (92.4 °C)...";
        currentStepNarrator = "Paso 5: Máquina de café COFFEE-01 activada. Bomba 9.2 bar, molienda y erogación a 92 °C.";

        if (coffeeLiquidStream != null)
        {
            coffeeLiquidStream.gameObject.SetActive(true);
        }

        yield return new WaitForSeconds(2.4f);

        if (coffeeLiquidStream != null)
        {
            coffeeLiquidStream.gameObject.SetActive(false);
        }

        currentTxState = TransactionState.DELIVERY_VERIFYING;
        transactionStatusMessage = "VERIFICANDO SERVICIO: FLUJO Y PRESIÓN DE CALDERA...";
        currentStepNarrator = "Paso 6: Sensores de flujo y temperatura confirman volumen y calor exacto servido en el vaso.";
        yield return new WaitForSeconds(1.2f);

        currentTxState = TransactionState.PROOF_OF_SERVICE;
        SetProofOfServiceState("VERIFIED");
        transactionStatusMessage = "PROOF OF SERVICE VERIFIED (Bebida Servida)";
        currentStepNarrator = "Paso 7: ¡Proof of Service Verificado! Café caliente listo para retirar.";
        yield return new WaitForSeconds(1.8f);

        currentTxState = TransactionState.CAPTURE;
        selectedItem.stock = Mathf.Max(0, selectedItem.stock - 1);
        selectedItem.itemState = "AVAILABLE";
        transactionStatusMessage = $"CAPTURA COMPLETADA (Stock: {selectedItem.stock})";
        currentStepNarrator = "Paso 8: Fondos capturados. Cliente retira su café.";

        if (!string.IsNullOrEmpty(currentTxId))
        {
            StartCoroutine(SendDispenseResultToBackend(currentTxId, true));
        }

        yield return new WaitForSeconds(1.6f);

        ResetAll3DQrDisplays();
        currentTxState = TransactionState.COMPLETED;
        transactionStatusMessage = "CAFÉ DISPENSADO CON ÉXITO";
        currentStepNarrator = "Demostración de café completada con éxito.";
    }

    public void StartFailureRecoveryDemo()
    {
        if (currentTxState != TransactionState.IDLE && currentTxState != TransactionState.COMPLETED) return;
        StartCoroutine(FailureAndRecoveryWorkflow());
    }

    private IEnumerator FailureAndRecoveryWorkflow()
    {
        MachineItem target = (vendingSnackItems.Count > 0) ? vendingSnackItems[0] : null;
        if (target == null) yield break;

        selectedItem = target;
        selectedItem.itemState = "RESERVED";
        currentTxId = $"GROG-ERR-{UnityEngine.Random.Range(100000, 999999)}";

        currentTxState = TransactionState.PAYMENT_AUTHORIZED;
        transactionStatusMessage = "PAGO AUTORIZADO -> INTENTO DE DISPENSADO";
        currentStepNarrator = "PASO 1: Pago autorizado por GROG Cloud. VMC ordena al motor dispensar producto.";
        yield return new WaitForSeconds(1.8f);

        currentTxState = TransactionState.DISPENSING;
        transactionStatusMessage = "FALLO MECÁNICO: MOTOR ATASCADO A 45°";
        currentStepNarrator = "PASO 2: FALLO DETECTADO. El resorte helicoidal sufre un atasco mecánico.";

        if (activeSpringTransforms.Count > 0 && activeSpringTransforms[0] != null)
        {
            Quaternion startRot = activeSpringTransforms[0].localRotation;
            activeSpringTransforms[0].localRotation = startRot * Quaternion.Euler(0f, 0f, -45f);
            yield return new WaitForSeconds(1.2f);
            activeSpringTransforms[0].localRotation = startRot;
        }

        currentTxState = TransactionState.NO_SERVICE_DETECTED;
        currentMeasuredDistance = 32.5f;
        transactionStatusMessage = "SENSOR HC-SR04: BANDEJA VACÍA (32.5 cm) — NO SERVICE";
        currentStepNarrator = "PASO 3: El sensor ultrasónico HC-SR04 confirma que la bandeja receptora sigue vacía.";
        yield return new WaitForSeconds(2.0f);

        currentTxState = TransactionState.DISPENSE_STATUS_UNKNOWN;
        SetProofOfServiceState("FAILURE");
        transactionStatusMessage = "PROOF OF SERVICE FAILED (DISPENSE_STATUS_UNKNOWN)";
        currentStepNarrator = "PASO 4: ALERTA CRÍTICA. Sin Proof of Service, GROG suspende la captura de fondos e inicia Recovery.";
        yield return new WaitForSeconds(2.2f);

        currentTxState = TransactionState.RECOVERY;
        transactionStatusMessage = "GROG RECOVERY ENGINE: CONCILIACIÓN TRANSACCIONAL";
        currentStepNarrator = "PASO 5: Motor de Recuperación analiza telemetría y confirma falla en la entrega.";
        yield return new WaitForSeconds(2.0f);

        currentTxState = TransactionState.RECONCILIATION;
        transactionStatusMessage = "CONCILIACIÓN COMPLETADA: REVERSIÓN APROBADA";
        yield return new WaitForSeconds(1.5f);

        currentTxState = TransactionState.REFUND;
        selectedItem.itemState = "AVAILABLE";
        transactionStatusMessage = "REEMBOLSO EJECUTADO (ZERO-LOSS REFUND)";
        currentStepNarrator = "PASO 6: Reembolso efectuado al método de pago del cliente. Dinero 100% protegido.";
        yield return new WaitForSeconds(2.5f);

        transactionStatusMessage = "GROG AI: ALERTA DE ATASCO REGISTRADA (Ticket #8241)";
        currentStepNarrator = "PASO 7: El AI Engine actualiza el índice de salud del motor de la ranura afectada y programa revisión.";
        yield return new WaitForSeconds(2.5f);

        SetProofOfServiceState("IDLE");
        currentTxState = TransactionState.IDLE;
        transactionStatusMessage = "SISTEMA EN REPOSO TRAS RECUPERACIÓN RESILIENTE";
        currentStepNarrator = "Demostración de resiliencia finalizada.";
    }

    private IEnumerator AnimateSpiral(Transform spiral)
    {
        float duration = 0.85f;
        float elapsed = 0f;
        Quaternion startRot = spiral.localRotation;
        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            float progress = Mathf.Clamp01(elapsed / duration);
            spiral.localRotation = startRot * Quaternion.Euler(0f, 0f, -progress * 360f);
            yield return null;
        }
        spiral.localRotation = startRot;
    }

    private IEnumerator AnimateSpiralAndPushSnack(Transform spiral, GameObject snack)
    {
        float duration = 0.95f;
        float elapsed = 0f;
        Quaternion startRot = spiral.localRotation;
        Vector3 snackStartPos = (snack != null) ? snack.transform.localPosition : Vector3.zero;
        Vector3 snackTargetPos = snackStartPos + new Vector3(0f, 0f, -0.22f);

        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            float progress = Mathf.Clamp01(elapsed / duration);
            spiral.localRotation = startRot * Quaternion.Euler(0f, 0f, -progress * 360f);
            if (snack != null)
            {
                snack.transform.localPosition = Vector3.Lerp(snackStartPos, snackTargetPos, progress);
            }
            yield return null;
        }
        spiral.localRotation = startRot;
    }

    public void InsertPhysicalCoin(float amount = 2.00f)
    {
        StartCoroutine(InsertPhysicalCoinRoutine(amount));
    }

    private IEnumerator InsertPhysicalCoinRoutine(float amount)
    {
        if (isPhysicalCoinProcessing) yield break;
        isPhysicalCoinProcessing = true;

        Transform coinSlot = null;
        if (activeMachineId == "VENDING-01")
        {
            GameObject go = GameObject.Find("Front_Coin_Slot");
            if (go != null) coinSlot = go.transform;
        }
        else if (activeMachineId == "COOLER-01")
        {
            GameObject go = GameObject.Find("Cooler_Coin_Slot");
            if (go != null) coinSlot = go.transform;
        }
        else
        {
            GameObject go = GameObject.Find("Necta_Coin_Slot");
            if (go != null) coinSlot = go.transform;
        }

        // Moneda física 3D dorada
        GameObject coin = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        coin.name = "Physical_Coin_MDB";
        coin.transform.localScale = new Vector3(0.065f, 0.007f, 0.065f);
        coin.transform.rotation = Quaternion.Euler(90f, 0f, 0f);

        Vector3 targetSlotPos = (coinSlot != null) ? coinSlot.position : new Vector3(-3.20f, 1.0f, -0.2f);
        Vector3 startPos = targetSlotPos + new Vector3(0f, 0.28f, -0.06f);
        coin.transform.position = startPos;

        Renderer rend = coin.GetComponent<Renderer>();
        if (rend != null)
        {
            rend.material.color = new Color(1.0f, 0.82f, 0.15f);
        }

        currentStepNarrator = $"Nivel 0 (Fiduciario): Inserción de moneda física de Bs {amount:F2} en ranura MDB...";
        
        float elapsed = 0f;
        float dur = 0.65f;
        while (elapsed < dur)
        {
            elapsed += Time.deltaTime;
            float t = Mathf.Clamp01(elapsed / dur);
            coin.transform.position = Vector3.Lerp(startPos, targetSlotPos, t * t);
            coin.transform.Rotate(0f, 180f * Time.deltaTime, 0f, Space.Self);
            yield return null;
        }

        elapsed = 0f;
        Vector3 origScale = coin.transform.localScale;
        while (elapsed < 0.18f)
        {
            elapsed += Time.deltaTime;
            coin.transform.localScale = Vector3.Lerp(origScale, Vector3.zero, elapsed / 0.18f);
            yield return null;
        }
        Destroy(coin);

        currentStepNarrator = $"Nivel 0: Monedero MDB valida diámetro y aleación electromagnética. Crédito: Bs {amount:F2}.";
        transactionStatusMessage = $"MDB CASH CREDIT: Bs {amount:F2}";

        if (selectedItem == null)
        {
            List<MachineItem> items = (activeMachineType == MachineType.VENDING_SNACKS) ? vendingSnackItems :
                                      (activeMachineType == MachineType.COLD_BEVERAGES ? coldDrinkItems : coffeeItems);
            if (items.Count > 0) selectedItem = items[0];
        }

        if (selectedItem != null)
        {
            showPaymentModal = false;
            currentTxState = TransactionState.PAYMENT_AUTHORIZED;
            currentTxId = $"CASH-{System.Guid.NewGuid().ToString().Substring(0, 8)}";
            transactionStatusMessage = $"PAGO FIDUCIARIO RECIBIDO: Bs {amount:F2}";
            
            StartCoroutine(SendCashTransactionToBackend(selectedItem, amount));
            
            yield return new WaitForSeconds(0.6f);
            StartCoroutine(ProcessAuthorizedTransaction());
        }

        isPhysicalCoinProcessing = false;
    }

    private IEnumerator SendCashTransactionToBackend(MachineItem item, float amount)
    {
        string url = $"{orchestratorUrl.TrimEnd('/')}/api/v1/transactions/init";
        string jsonPayload = $"{{\"machine_id\":\"{item.machineId}\",\"product_id\":\"{item.id}\",\"amount\":{item.price:F2},\"payment_method\":\"CASH\"}}";

        using (UnityWebRequest req = new UnityWebRequest(url, "POST"))
        {
            byte[] body = System.Text.Encoding.UTF8.GetBytes(jsonPayload);
            req.uploadHandler = new UploadHandlerRaw(body);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            req.SetRequestHeader("ngrok-skip-browser-warning", "1");
            req.timeout = 5;
            yield return req.SendWebRequest();
            if (req.result == UnityWebRequest.Result.Success)
            {
                Debug.Log($"[GROG Nivel 0] Transacción CASH sincronizada en CRM Cloud: {req.downloadHandler.text}");
            }
        }
    }

    public void ClearDispensedTray()
    {
        for (int i = dispensedTrayObjects.Count - 1; i >= 0; i--)
        {
            if (dispensedTrayObjects[i] != null) Destroy(dispensedTrayObjects[i]);
        }
        dispensedTrayObjects.Clear();
        currentMeasuredDistance = 32.5f;
        transactionStatusMessage = "BANDEJA DE RECOGIDA LIMPIA (32.5 cm)";
        currentStepNarrator = "Sensor HC-SR04 confirma tolva vacía tras retirada del producto.";
    }

    private void SetProofOfServiceState(string state)
    {
        if (proofOfServiceBadge == null) return;
        if (state == "VERIFIED" && matProofVerified != null)
        {
            proofOfServiceBadge.material = matProofVerified;
        }
        else if (state == "FAILURE" && matProofFailure != null)
        {
            proofOfServiceBadge.material = matProofFailure;
        }
        else if (matProofIdle != null)
        {
            proofOfServiceBadge.material = matProofIdle;
        }
    }

    private IEnumerator SendDispenseResultToBackend(string txId, bool success)
    {
        string resultUrl = $"{orchestratorUrl.TrimEnd('/')}/api/v1/transactions/{txId}/dispense-result";
        string payload = $"{{\"success\":{(success ? "true" : "false")}}}";

        using (UnityWebRequest req = new UnityWebRequest(resultUrl, "POST"))
        {
            byte[] body = Encoding.UTF8.GetBytes(payload);
            req.uploadHandler = new UploadHandlerRaw(body);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            req.SetRequestHeader("ngrok-skip-browser-warning", "1");
            req.timeout = 5;

            yield return req.SendWebRequest();

            if (req.result == UnityWebRequest.Result.Success)
            {
                Debug.Log($"[GROG Cloud] Dispense-result reportado exitosamente a {resultUrl} para TX {txId}!");
            }
            else
            {
                Debug.LogWarning($"[GROG Cloud] Error reportando dispense-result al backend: {req.error}");
            }
        }
    }

    private Texture2D GenerateProceduralQrTexture(string itemId, float price)
    {
        int size = 160;
        Texture2D tex = new Texture2D(size, size, TextureFormat.RGBA32, false);
        tex.filterMode = FilterMode.Point;
        Color bg = Color.white;
        Color fg = Color.black;

        int seed = (itemId.GetHashCode() + (int)(price * 100)) & 0x7FFFFFFF;
        System.Random rng = new System.Random(seed);

        for (int y = 0; y < size; y++)
        {
            for (int x = 0; x < size; x++)
            {
                int blockX = x / 8;
                int blockY = y / 8;

                bool isFinderTL = (blockX < 7 && blockY < 7);
                bool isFinderTR = (blockX >= 13 && blockY < 7);
                bool isFinderBL = (blockX < 7 && blockY >= 13);

                if (isFinderTL || isFinderTR || isFinderBL)
                {
                    int localX = blockX < 7 ? blockX : (blockX - 13);
                    int localY = blockY < 7 ? blockY : (blockY - 13);
                    bool border = (localX == 0 || localX == 6 || localY == 0 || localY == 6);
                    bool center = (localX >= 2 && localX <= 4 && localY >= 2 && localY <= 4);
                    tex.SetPixel(x, y, (border || center) ? fg : bg);
                }
                else
                {
                    bool isPixel = (rng.Next(0, 100) > 52);
                    tex.SetPixel(x, y, isPixel ? fg : bg);
                }
            }
        }
        tex.Apply();
        return tex;
    }
    #endregion

    #region Modo Instalador / Vinculación de Máquinas
    [System.Serializable]
    private class PairingTokenRequest
    {
        public string machine_id;
        public string machine_type;
        public string environment;
        public string protocol;
        public string brand_model;
    }

    [System.Serializable]
    private class PairingTokenResponse
    {
        public string status;
        public string machine_id;
        public string pairing_code;
        public string pairing_token;
        public string qr_image;
        public float expires_in;
        public string machine_type;
        public string environment;
        public string name;
    }

    [System.Serializable]
    private class ProvisioningStatusResponse
    {
        public string machine_id;
        public bool is_claimed;
        public string owner_email;
        public bool has_active_token;
        public int seconds_left;
        public string name;
    }

    public void ToggleInstallerMode()
    {
        showInstallerModal = !showInstallerModal;
        if (showInstallerModal)
        {
            StartCoroutine(RequestPairingTokenWorker(activeMachineId));
        }
        else
        {
            if (pollPairingCoroutine != null) StopCoroutine(pollPairingCoroutine);
            ResetAll3DQrDisplays();
        }
    }

    private IEnumerator RequestPairingTokenWorker(string machineId)
    {
        isPairingRequesting = true;
        isMachineClaimed = false;
        claimedOwnerEmail = "";
        pairingPin = "GENERANDO...";
        currentStepNarrator = $"MODO INSTALADOR: Solicitando PIN de activación para {machineId} al servidor...";

        string mType = "SNACK_VENDING";
        if (machineId == "COOLER-01") mType = "COOLER_DRINKS";
        else if (machineId == "COFFEE-01") mType = "COFFEE_MACHINE";

        PairingTokenRequest payload = new PairingTokenRequest
        {
            machine_id = machineId,
            machine_type = mType,
            environment = "SIMULATED",
            protocol = "MDB",
            brand_model = "GROG Unity Twin v2"
        };

        string json = JsonUtility.ToJson(payload);
        string url = $"{vendingUrl.TrimEnd('/')}/api/v1/machines/provisioning/generate-token";

        using (UnityWebRequest req = new UnityWebRequest(url, "POST"))
        {
            byte[] bodyRaw = System.Text.Encoding.UTF8.GetBytes(json);
            req.uploadHandler = new UploadHandlerRaw(bodyRaw);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            req.timeout = 5;

            yield return req.SendWebRequest();

            isPairingRequesting = false;

            if (req.result == UnityWebRequest.Result.Success)
            {
                PairingTokenResponse resp = JsonUtility.FromJson<PairingTokenResponse>(req.downloadHandler.text);
                pairingPin = resp.pairing_code;
                pairingToken = resp.pairing_token;
                pairingSecondsLeft = resp.expires_in;

                // Cargar imagen QR real del backend
                if (!string.IsNullOrEmpty(resp.qr_image))
                {
                    try
                    {
                        string b64 = resp.qr_image.Contains(",") ? resp.qr_image.Substring(resp.qr_image.IndexOf(",") + 1) : resp.qr_image;
                        byte[] imgBytes = System.Convert.FromBase64String(b64);
                        Texture2D realQrTex = new Texture2D(256, 256, TextureFormat.RGBA32, false);
                        realQrTex.filterMode = FilterMode.Point;
                        realQrTex.LoadImage(imgBytes);
                        pairingQrTexture = realQrTex;
                    }
                    catch
                    {
                        pairingQrTexture = GenerateProceduralQrTexture(resp.pairing_token, 999f);
                    }
                }
                else
                {
                    pairingQrTexture = GenerateProceduralQrTexture(resp.pairing_token, 999f);
                }

                UpdateMachine3DQrDisplays(pairingQrTexture, machineId);

                currentStepNarrator = $"MODO INSTALADOR ACTIVO: PIN generado [{pairingPin}] para {machineId}. Ingrese el código en la App GROG.";

                if (pollPairingCoroutine != null) StopCoroutine(pollPairingCoroutine);
                pollPairingCoroutine = StartCoroutine(PollPairingStatusWorker(machineId));
            }
            else
            {
                pairingPin = "ERROR";
                currentStepNarrator = $"MODO INSTALADOR: Error conectando con {url} ({req.error}).";
            }
        }
    }

    private IEnumerator FactoryResetWorker(string machineId)
    {
        isRebooting = true;
        pairingPin = "REINICIANDO...";
        currentStepNarrator = $"🔄 BOTÓN ILUMINADO ACCIONADO: Desvinculando {machineId} de propietario anterior y reiniciando VMC...";

        ResetAll3DQrDisplays();
        yield return new WaitForSeconds(1.0f);

        string url = $"{vendingUrl.TrimEnd('/')}/api/v1/machines/{machineId}/factory-reset";

        using (UnityWebRequest req = UnityWebRequest.PostWwwForm(url, ""))
        {
            req.SetRequestHeader("ngrok-skip-browser-warning", "1");
            req.timeout = 5;
            yield return req.SendWebRequest();

            isRebooting = false;

            if (req.result == UnityWebRequest.Result.Success)
            {
                PairingTokenResponse resp = JsonUtility.FromJson<PairingTokenResponse>(req.downloadHandler.text);
                pairingPin = resp.pairing_code;
                pairingToken = resp.pairing_token;
                pairingSecondsLeft = resp.expires_in;
                isMachineClaimed = false;
                claimedOwnerEmail = "";

                if (!string.IsNullOrEmpty(resp.qr_image))
                {
                    try
                    {
                        string b64 = resp.qr_image.Contains(",") ? resp.qr_image.Substring(resp.qr_image.IndexOf(",") + 1) : resp.qr_image;
                        byte[] imgBytes = System.Convert.FromBase64String(b64);
                        Texture2D realQrTex = new Texture2D(256, 256, TextureFormat.RGBA32, false);
                        realQrTex.filterMode = FilterMode.Point;
                        realQrTex.LoadImage(imgBytes);
                        pairingQrTexture = realQrTex;
                    }
                    catch
                    {
                        pairingQrTexture = GenerateProceduralQrTexture(resp.pairing_token, 999f);
                    }
                }
                else
                {
                    pairingQrTexture = GenerateProceduralQrTexture(resp.pairing_token, 999f);
                }

                UpdateMachine3DQrDisplays(pairingQrTexture, machineId);

                currentStepNarrator = $"✅ RESET COMPLETADO: {machineId} desvinculada del dueño anterior. Nuevo PIN [{pairingPin}] listo para nueva cuenta.";

                if (pollPairingCoroutine != null) StopCoroutine(pollPairingCoroutine);
                pollPairingCoroutine = StartCoroutine(PollPairingStatusWorker(machineId));
            }
            else
            {
                pairingPin = "ERROR";
                currentStepNarrator = $"Error restableciendo máquina en backend: {req.error}";
            }
        }
    }

    private IEnumerator PollPairingStatusWorker(string machineId)
    {
        string statusUrl = $"{vendingUrl.TrimEnd('/')}/api/v1/machines/provisioning/status/{machineId}";
        while (showInstallerModal && !isMachineClaimed)
        {
            yield return new WaitForSeconds(2.0f);

            using (UnityWebRequest req = UnityWebRequest.Get(statusUrl))
            {
                req.SetRequestHeader("ngrok-skip-browser-warning", "1");
                req.timeout = 3;
                yield return req.SendWebRequest();

                if (req.result == UnityWebRequest.Result.Success)
                {
                    ProvisioningStatusResponse st = JsonUtility.FromJson<ProvisioningStatusResponse>(req.downloadHandler.text);
                    if (st.is_claimed && !string.IsNullOrEmpty(st.owner_email) && st.owner_email != "pending@grog.com")
                    {
                        isMachineClaimed = true;
                        claimedOwnerEmail = st.owner_email;
                        currentStepNarrator = $"¡VINCULACIÓN EXITOSA! Máquina {machineId} asignada al propietario: {claimedOwnerEmail}.";

                        yield return new WaitForSeconds(3.5f);
                        showInstallerModal = false;
                        ResetAll3DQrDisplays();
                        yield break;
                    }
                }
            }
        }
    }

    private void DrawInstallerModal()
    {
        float mw = 460;
        float mh = 570;
        Rect modalRect = new Rect((Screen.width - mw) / 2f, (Screen.height - mh) / 2f, mw, mh);

        GUI.Box(new Rect(0, 0, Screen.width, Screen.height), GUIContent.none);
        GUI.Box(modalRect, GUIContent.none);

        float pad = 16;
        float y = modalRect.y + pad;
        float w = mw - (pad * 2);

        GUIStyle richStyle = new GUIStyle(GUI.skin.label) { richText = true, wordWrap = true };

        GUI.Label(new Rect(modalRect.x + pad, y, w, 28),
            "<size=15><b>🛠️ MODO INSTALADOR Y SERVICIO TÉCNICO</b></size>", richStyle);
        y += 28;

        string machDesc = activeMachineId == "VENDING-01" ? "Expendedora de Snacks" :
                          (activeMachineId == "COOLER-01" ? "Bebidas Refrigeradas" : "Cafetería Especial");

        GUI.Label(new Rect(modalRect.x + pad, y, w, 22),
            $"<color=#38BDF8><b>Máquina: {activeMachineId} — {machDesc} [Virtual]</b></color>", richStyle);
        y += 26;

        // ─── BOTÓN ILUMINADO DE RESET Y DESVINCULACIÓN DE PROPIETARIO ───
        float pulse = (Mathf.Sin(Time.time * 6f) + 1f) * 0.5f;
        Color ledColor = Color.Lerp(new Color(1f, 0.2f, 0.05f), new Color(1f, 0.85f, 0.15f), pulse);
        GUI.color = isRebooting ? Color.gray : ledColor;

        if (GUI.Button(new Rect(modalRect.x + pad, y, w, 38),
            isRebooting ? "⏳ REINICIANDO VMC Y DESVINCULANDO..." : "🔘 [BOTÓN ILUMINADO DE SERVICIO: REINICIAR Y DESVINCULAR]"))
        {
            StartCoroutine(FactoryResetWorker(activeMachineId));
        }
        GUI.color = Color.white;
        y += 42;

        GUI.Label(new Rect(modalRect.x + pad, y, w, 34),
            "<size=9><color=#FCD34D>💡 <i>Presione el botón iluminado para simular el interruptor físico interior. Borra el dueño actual de la nube y genera un código nuevo para transferirla a otra cuenta.</i></color></size>", richStyle);
        y += 38;

        // PIN DE 6 DÍGITOS DESTACADO
        GUI.Box(new Rect(modalRect.x + pad, y, w, 70), GUIContent.none);
        GUI.Label(new Rect(modalRect.x + pad + 8, y + 6, w - 16, 20),
            "<size=10><b>CÓDIGO PIN DE ACTIVACIÓN (6 DÍGITOS):</b></size>", richStyle);

        string pinDisplay = isRebooting ? "REINICIANDO..." : (isPairingRequesting ? "GENERANDO..." : (string.IsNullOrEmpty(pairingPin) ? "------" : pairingPin));
        GUI.Label(new Rect(modalRect.x + pad, y + 26, w, 38),
            $"<size=26><color=yellow><b>  {pinDisplay}  </b></color></size>", richStyle);
        y += 76;

        int mins = Mathf.FloorToInt(pairingSecondsLeft / 60f);
        int secs = Mathf.FloorToInt(pairingSecondsLeft % 60f);
        string timerColor = pairingSecondsLeft > 60f ? "#38BDF8" : "#EF4444";
        GUI.Label(new Rect(modalRect.x + pad, y, w, 20),
            $"<size=11>⏱️ <b>Tiempo restante de PIN/QR:</b> <color={timerColor}><b>{mins:D2}:{secs:D2} min</b></color></size>", richStyle);
        y += 24;

        // CÓDIGO QR REAL ESCANEABLE
        if (pairingQrTexture != null)
        {
            float qrSize = 135;
            Rect qrRect = new Rect(modalRect.x + (mw - qrSize) / 2f, y, qrSize, qrSize);
            GUI.DrawTexture(qrRect, pairingQrTexture);
            y += qrSize + 8;
        }
        else
        {
            y += 18;
        }

        if (isMachineClaimed)
        {
            GUI.Box(new Rect(modalRect.x + pad, y, w, 44), GUIContent.none);
            GUI.Label(new Rect(modalRect.x + pad + 8, y + 4, w - 16, 36),
                $"<color=#4ADE80><b>✅ ¡MÁQUINA VINCULADA CON ÉXITO!</b>\nPropietario asignado: {claimedOwnerEmail}</color>", richStyle);
        }
        else
        {
            GUI.Label(new Rect(modalRect.x + pad, y, w, 32),
                $"<size=10><color=#9CA3AF>Escanee el QR con la cámara de la App GROG o ingrese el PIN de 6 dígitos.\nToken: {pairingToken}</color></size>", richStyle);
        }
        y += 38;

        if (GUI.Button(new Rect(modalRect.x + pad, modalRect.y + mh - 42, w, 30), "✖ Salir del Modo Instalador"))
        {
            ToggleInstallerMode();
        }
    }
    #endregion

    #region Interfaz de Usuario de Escritorio (Desktop Window)
    private void OnGUI()
    {
        GUI.color = showUI ? new Color(0.2f, 0.8f, 1.0f) : new Color(1.0f, 0.8f, 0.2f);
        if (GUI.Button(new Rect(15, 12, 175, 28), showUI ? "👁 Ocultar HUD (H)" : "👁 Mostrar HUD (H)"))
        {
            showUI = !showUI;
        }
        GUI.color = Color.white;

        GUI.color = showInstallerModal ? Color.green : new Color(1.0f, 0.65f, 0.1f);
        if (GUI.Button(new Rect(198, 12, 190, 28), showInstallerModal ? "🛠️ Modo Técnico: ACTIVO" : "🛠️ Vincular Máquina (I/M)"))
        {
            ToggleInstallerMode();
        }
        GUI.color = Color.white;

        GUI.color = new Color(1.0f, 0.82f, 0.15f);
        if (GUI.Button(new Rect(394, 12, 185, 28), "💰 Insertar Moneda (Nivel 0)"))
        {
            InsertPhysicalCoin(2.00f);
        }
        GUI.color = Color.white;

        // Barra inferior: Narrador técnico
        GUI.Box(new Rect(15, Screen.height - 46, Screen.width - 30, 38), GUIContent.none);
        GUI.Label(new Rect(25, Screen.height - 44, Screen.width - 50, 34),
            $"<b>EXPLICACIÓN TÉCNICA:</b> <color=yellow>{currentStepNarrator}</color>");

        if (!showUI) return;

        // Banner Superior
        GUI.Box(new Rect(586, 10, Screen.width - 601, 32), GUIContent.none);
        GUI.Label(new Rect(596, 12, Screen.width - 615, 26),
            "<b>GROG DIGITAL TWIN</b> — Plataforma Universal IoT + FinTech: 3 Máquinas Independientes");

        DrawDesktopWindow();

        if (showPaymentModal && selectedItem != null)
        {
            DrawPaymentModal();
        }

        if (showInstallerModal)
        {
            DrawInstallerModal();
        }
    }

    private void DrawDesktopWindow()
    {
        windowRect.x = Mathf.Clamp(windowRect.x, 0, Screen.width - 100);
        windowRect.y = Mathf.Clamp(windowRect.y, 0, Screen.height - 60);

        if (isMinimized)
        {
            windowRect.height = 36;
        }

        GUI.Box(windowRect, GUIContent.none);

        // Barra de Título Arrastrable
        Rect titleBarRect = new Rect(windowRect.x, windowRect.y, windowRect.width, 32);
        GUI.Box(titleBarRect, GUIContent.none);

        GUI.Label(new Rect(windowRect.x + 12, windowRect.y + 6, windowRect.width - 120, 22),
            $"<b>GROG Control Center</b> [Máquina Activa: {activeMachineId}]");

        float btnSize = 22;
        float btnY = windowRect.y + 5;
        float rightX = windowRect.x + windowRect.width - 80;

        if (GUI.Button(new Rect(rightX, btnY, btnSize, btnSize), "-"))
        {
            isMinimized = !isMinimized;
            if (!isMinimized && isMaximized) windowRect.height = Screen.height - 110;
            else if (!isMinimized) windowRect.height = 600;
        }

        if (GUI.Button(new Rect(rightX + 24, btnY, btnSize, btnSize), isMaximized ? "❐" : "□"))
        {
            if (!isMaximized)
            {
                preMaximizeRect = windowRect;
                windowRect = new Rect(20, 50, Screen.width - 40, Screen.height - 110);
                isMaximized = true;
                isMinimized = false;
            }
            else
            {
                windowRect = preMaximizeRect;
                isMaximized = false;
            }
        }

        if (GUI.Button(new Rect(rightX + 48, btnY, btnSize, btnSize), "X"))
        {
            showUI = false;
        }

        Event ev = Event.current;
        if (ev.type == EventType.MouseDown && titleBarRect.Contains(ev.mousePosition) && ev.button == 0)
        {
            GUIUtility.hotControl = 12345;
        }
        if (GUIUtility.hotControl == 12345 && ev.type == EventType.MouseDrag)
        {
            windowRect.x += ev.delta.x;
            windowRect.y += ev.delta.y;
        }
        if (ev.type == EventType.MouseUp && GUIUtility.hotControl == 12345)
        {
            GUIUtility.hotControl = 0;
        }

        if (isMinimized) return;

        // Selector Central de las TRES MÁQUINAS INDEPENDIENTES
        float contentY = windowRect.y + 36;
        float pad = 12;
        float usableW = windowRect.width - (pad * 2);

        GUI.Label(new Rect(windowRect.x + pad, contentY, usableW - 145, 20), "<b>SELECTOR DE MÁQUINA DE AUTOSERVICIO:</b>");
        GUI.color = showInstallerModal ? Color.green : new Color(1.0f, 0.65f, 0.1f);
        if (GUI.Button(new Rect(windowRect.x + pad + usableW - 140, contentY - 2, 140, 22), "<size=9>🛠️ Vincular Activa (I)</size>"))
        {
            ToggleInstallerMode();
        }
        GUI.color = Color.white;

        float machBtnW = (usableW - 12) / 3f;

        GUI.color = (activeMachineId == "VENDING-01") ? Color.cyan : Color.white;
        if (GUI.Button(new Rect(windowRect.x + pad, contentY + 22, machBtnW, 32), "🥫 EXPENDEDORA\n<size=9>[VENDING-01]</size>"))
        {
            SwitchActiveMachine("VENDING-01");
        }

        GUI.color = (activeMachineId == "COOLER-01") ? Color.cyan : Color.white;
        if (GUI.Button(new Rect(windowRect.x + pad + machBtnW + 6, contentY + 22, machBtnW, 32), "🧊 BEBIDAS REFRIG.\n<size=9>[COOLER-01]</size>"))
        {
            SwitchActiveMachine("COOLER-01");
        }

        GUI.color = (activeMachineId == "COFFEE-01") ? Color.cyan : Color.white;
        if (GUI.Button(new Rect(windowRect.x + pad + ((machBtnW + 6) * 2), contentY + 22, machBtnW, 32), "☕ CAFÉ ESPECIAL.\n<size=9>[COFFEE-01]</size>"))
        {
            SwitchActiveMachine("COFFEE-01");
        }
        GUI.color = Color.white;

        // Pestañas
        float tabY = contentY + 60;
        string[] tabs = new string[] { "MÁQUINA", "CONTROL CENTER", "PAGO", "MDB", "EDGE", "TX", "TELEM", "AI" };
        float tabW = usableW / tabs.Length;

        for (int t = 0; t < tabs.Length; t++)
        {
            GUI.color = (currentTab == t) ? Color.cyan : Color.white;
            if (GUI.Button(new Rect(windowRect.x + pad + (t * tabW), tabY, tabW - 2, 26), $"<size=8>{tabs[t]}</size>"))
            {
                currentTab = t;
            }
        }
        GUI.color = Color.white;

        // Área con scroll
        float areaY = tabY + 30;
        float areaH = windowRect.height - (areaY - windowRect.y) - 24;
        Rect contentArea = new Rect(windowRect.x + pad, areaY, usableW, areaH);
        Rect viewArea = new Rect(0, 0, usableW - 20, 880);

        scrollPos = GUI.BeginScrollView(contentArea, scrollPos, viewArea);

        DrawTabContent(viewArea.width);

        GUI.EndScrollView();

        // Agarre de Redimensionamiento
        if (!isMaximized)
        {
            Rect resizeRect = new Rect(windowRect.x + windowRect.width - 18, windowRect.y + windowRect.height - 18, 18, 18);
            GUI.Box(resizeRect, "◢");

            if (ev.type == EventType.MouseDown && resizeRect.Contains(ev.mousePosition) && ev.button == 0)
            {
                isResizing = true;
                resizeStartPos = ev.mousePosition;
                resizeStartSize = new Vector2(windowRect.width, windowRect.height);
                ev.Use();
            }
            if (isResizing && ev.type == EventType.MouseDrag)
            {
                Vector2 diff = ev.mousePosition - resizeStartPos;
                windowRect.width = Mathf.Max(420, resizeStartSize.x + diff.x);
                windowRect.height = Mathf.Max(340, resizeStartSize.y + diff.y);
                ev.Use();
            }
            if (isResizing && ev.type == EventType.MouseUp)
            {
                isResizing = false;
                ev.Use();
            }
        }
    }

    private void DrawTabContent(float width)
    {
        float y = 8;

        switch (currentTab)
        {
            // TAB 0: MÁQUINA ACTIVA (Catálogo y Botón [COMPRAR] / [SELECCIONAR])
            case 0:
                string title = (activeMachineId == "VENDING-01")
                    ? "MÁQUINA 1: EXPENDEDORA DE SNACKS Y SÓLIDOS (VENDING-01)"
                    : (activeMachineId == "COOLER-01")
                        ? "MÁQUINA 2: REFRIGERADOR DE BEBIDAS A 4.2 °C (COOLER-01)"
                        : "MÁQUINA 3: CAFÉ Y BEBIDAS CALIENTES (COFFEE-01)";

                GUI.Label(new Rect(0, y, width, 22), $"<b>{title}</b>");
                y += 24;

                List<MachineItem> currentItems = (activeMachineType == MachineType.VENDING_SNACKS)
                    ? vendingSnackItems
                    : (activeMachineType == MachineType.COLD_BEVERAGES ? coldDrinkItems : coffeeItems);

                for (int i = 0; i < currentItems.Count; i++)
                {
                    MachineItem item = currentItems[i];
                    Rect cardRect = new Rect(0, y, width, 68);
                    GUI.Box(cardRect, GUIContent.none);

                    GUI.color = item.color;
                    string icon = (item.category == "COFFEE") ? "☕" : (item.category == "DRINK" ? "🧊" : "🍫");
                    GUI.Box(new Rect(6, y + 8, 48, 52), icon);
                    GUI.color = Color.white;

                    GUI.Label(new Rect(60, y + 6, width - 170, 20), $"<b>{item.name}</b>");
                    GUI.Label(new Rect(60, y + 24, width - 170, 18), $"<size=10>ID: {item.id} | Slot: #{item.slotNumber} | Máq: {item.machineId}</size>");
                    GUI.Label(new Rect(60, y + 42, width - 170, 18), $"<size=11>Precio: <b>Bs {item.price:F2}</b> | Stock: <b>{item.stock}/{item.maxStock}</b></size>");

                    GUI.color = (item.stock > 0) ? new Color(0.2f, 1.0f, 0.4f) : Color.gray;
                    string btnTxt = (item.stock > 0) ? "COMPRAR\n(QR)" : "AGOTADO";
                    if (GUI.Button(new Rect(width - 165, y + 12, 78, 44), btnTxt) && item.stock > 0)
                    {
                        SelectProductToBuy(item);
                    }
                    GUI.color = (item.stock > 0) ? new Color(1.0f, 0.85f, 0.2f) : Color.gray;
                    if (GUI.Button(new Rect(width - 82, y + 12, 78, 44), "<size=9>💰 MONEDA\n(Nivel 0)</size>") && item.stock > 0)
                    {
                        selectedItem = item;
                        InsertPhysicalCoin(item.price);
                    }
                    GUI.color = Color.white;

                    y += 74;
                }

                if (dispensedTrayObjects.Count > 0)
                {
                    y += 4;
                    GUI.color = new Color(0.3f, 0.8f, 1.0f);
                    if (GUI.Button(new Rect(0, y, width, 30), $"🖐 RECOGER PRODUCTO DE LA TOLVA ({dispensedTrayObjects.Count} en bandeja)"))
                    {
                        ClearDispensedTray();
                    }
                    GUI.color = Color.white;
                    y += 34;
                }

                if (activeMachineType == MachineType.COLD_BEVERAGES)
                {
                    y += 6;
                    GUI.color = isCoolerDoorOpen ? new Color(1.0f, 0.7f, 0.2f) : new Color(0.3f, 0.8f, 1.0f);
                    string doorTxt = isCoolerDoorOpen ? "🚪 Cerrar Puerta del Refrigerador" : "🚪 Abrir Puerta del Refrigerador (4.2 °C)";
                    if (GUI.Button(new Rect(0, y, width, 32), doorTxt))
                    {
                        ToggleCoolerDoor();
                    }
                    GUI.color = Color.white;
                    y += 38;
                }
                break;

            // TAB 1: CONTROL CENTER MULTI-MÁQUINA (3 MÁQUINAS SIMULTÁNEAS)
            case 1:
                GUI.Label(new Rect(0, y, width, 22), "<b>GROG CONTROL CENTER — SUPERVISIÓN DE FLOTA DE AUTOSERVICIO</b>");
                y += 24;

                // Card Máquina 1
                GUI.Box(new Rect(0, y, width, 88), GUIContent.none);
                GUI.Label(new Rect(8, y + 6, width - 16, 80),
                    "<b>1. EXPENDEDORA DE SNACKS (VENDING-01)</b>\n" +
                    "• Estado: <color=green>ONLINE</color> | Actuador: Motores Espirales 3D | Sensor: HC-SR04 (32.5 cm)\n" +
                    "• Interfaz: MDB Level 3 (Maestro VMC @ 9600 Baud)\n" +
                    "• Inventario: <b>82% Disponible</b> (78 items) | Alertas: Ninguna");
                y += 94;

                // Card Máquina 2
                GUI.Box(new Rect(0, y, width, 88), GUIContent.none);
                GUI.Label(new Rect(8, y + 6, width - 16, 80),
                    "<b>2. REFRIGERADOR DE BEBIDAS (COOLER-01)</b>\n" +
                    "• Estado: <color=green>ONLINE</color> | Actuador: Compuerta Gravitatoria | Temp: <color=cyan>4.2 °C</color>\n" +
                    "• Interfaz: GROG Universal Machine Adapter (Relé / Serial)\n" +
                    "• Inventario: <b>85% Disponible</b> (47 botellas/latas) | Compresor: 91% Salud");
                y += 94;

                // Card Máquina 3
                GUI.Box(new Rect(0, y, width, 88), GUIContent.none);
                GUI.Label(new Rect(8, y + 6, width - 16, 80),
                    "<b>3. CAFETERA PROFESIONAL (COFFEE-01)</b>\n" +
                    "• Estado: <color=green>ONLINE</color> | Caldera: <color=orange>92.4 °C (9.2 bar)</color> | Bomba: OK\n" +
                    "• Interfaz: GROG Universal Machine Adapter (Serial Propietario / MDB)\n" +
                    "• Inventario: Insumos OK (Café, Leche, Cacao, Azúcar) | Sensor Flujo: Calibrado");
                y += 94;

                // Resumen de Infraestructura
                GUI.Box(new Rect(0, y, width, 82), GUIContent.none);
                GUI.Label(new Rect(8, y + 6, width - 16, 72),
                    "<b>INFRAESTRUCTURA UNIVERSAL GROG:</b>\n" +
                    "• <b>3 Máquinas Físicas</b> compartiendo el mismo Ecosistema Cloud + Edge.\n" +
                    "• Transacciones normalizadas en capa Payment Service.\n" +
                    "• Verificación física multi-evidencia antes de liquidar (Proof of Service).");
                y += 88;
                break;

            // TAB 2: PAGO (Abstracción de Pagos)
            case 2:
                GUI.Label(new Rect(0, y, width, 22), "<b>ABSTRACCIÓN UNIVERSAL DE PAGOS GROG:</b>");
                y += 24;

                GUI.Box(new Rect(0, y, width, 140), GUIContent.none);
                GUI.Label(new Rect(10, y + 6, width - 20, 128),
                    "<size=10><b>FLUJO DE PAGO DESACOPLADO DEL PROTOCOLO DE MÁQUINA:</b>\n\n" +
                    "1. Métodos aceptados: <b>QR Dinámico, NFC, Tarjeta EMV Contactless, Billetera Móvil, RFID, Efectivo</b>.\n" +
                    "2. <b>Payment Abstraction Layer</b> normaliza los métodos en una solicitud unificada.\n" +
                    "3. <b>GROG Payment Service (Cloud)</b> procesa y autoriza los fondos con el banco/SimuPay.\n" +
                    "4. Solo tras autorización, GROG Edge instruye al controlador de la máquina dispensar.\n" +
                    "<i>Regla de Oro: MDB NO es el protocolo de pago QR; MDB es la interfaz entre el VMC y periféricos de máquina.</i></size>");
                y += 148;

                GUI.Label(new Rect(0, y, width, 20), "<b>MÉTODOS ACTIVOS EN LA PLATAFORMA:</b>");
                y += 22;
                string[] methods = new string[] { "✔ QR Dinámico (SimuPay / Bank)", "✔ NFC / Contactless", "✔ Tarjeta Chip EMV", "✔ Billetera Móvil (Wallet)", "✔ RFID Token", "✔ Efectivo (Coin/Bill MDB)" };
                for (int m = 0; m < methods.Length; m++)
                {
                    GUI.Label(new Rect(10, y, width - 20, 18), $"<size=11>{methods[m]}</size>");
                    y += 20;
                }
                break;

            // TAB 3: MDB INDUSTRIAL ARCHITECTURE
            case 3:
                GUI.Label(new Rect(0, y, width, 22), "<b>ARQUITECTURA MDB (MULTI-DROP BUS):</b>");
                y += 24;

                GUI.Box(new Rect(0, y, width, 160), GUIContent.none);
                GUI.Label(new Rect(10, y + 6, width - 20, 148),
                    "<size=10><b>ESTÁNDAR NAMA / EVA-CVS MDB LEVEL 3:</b>\n" +
                    "• <b>VMC (Vending Machine Controller):</b> Maestro del bus serie a 9600 Baud.\n" +
                    "• <b>GROG Universal Machine Adapter:</b> Interfaz sniffer/control que traduce tramas MDB sin alterar el hardware original.\n" +
                    "• <b>Coin Changer:</b> Validador y tubos de monedas (Dirección MDB 0x08).\n" +
                    "• <b>Bill Validator:</b> Aceptador y apilador de billetes (Dirección MDB 0x30).\n" +
                    "• <b>Cashless Terminal:</b> Terminal de cobro digital MDB (Dirección MDB 0x10).\n" +
                    "• <b>Card Reader:</b> Lector de tarjetas magnéticas/chip (Dirección MDB 0x60).</size>");
                y += 168;

                GUI.Label(new Rect(0, y, width, 20), "<b>ESTADO DEL BUS INDUSTRIAL:</b>");
                y += 22;
                GUI.Box(new Rect(0, y, width, 70), GUIContent.none);
                GUI.Label(new Rect(10, y + 6, width - 20, 58),
                    $"• Velocidad: <b>9600 Baud (9 bits, 1 Stop)</b>\n" +
                    $"• Estado VMC: <color=green>{vmcStatus}</color>\n" +
                    $"• Modo Adaptador: <color=cyan>{adapterStatus}</color>");
                y += 76;
                break;

            // TAB 4: GROG UNIVERSAL EDGE & ADAPTADORES
            case 4:
                GUI.Label(new Rect(0, y, width, 22), "<b>GROG UNIVERSAL EDGE & ADAPTADOR MODULAR:</b>");
                y += 24;

                GUI.Box(new Rect(0, y, width, 180), GUIContent.none);
                GUI.Label(new Rect(10, y + 6, width - 20, 168),
                    "<size=10><b>ARQUITECTURA MODULAR DE HARDWARE:</b>\n\n" +
                    "1. <b>CONTROLADOR EDGE (ESP32):</b>\n" +
                    "   - Conectividad Wi-Fi 4G / MQTT / HTTPS / WSS.\n" +
                    "   - Buffer transaccional offline y watchdog de hardware.\n" +
                    "   - Criptografía HMAC / TLS para seguridad bancaria.\n\n" +
                    "2. <b>UNIVERSAL MACHINE ADAPTER:</b>\n" +
                    "   - Módulo desacoplado con aislamiento galvánico.\n" +
                    "   - Soporta: MDB (Vending), Pulse (Arcade/Locker), Relé/Serial (Cafeteras industriales / Refrigeradores), Propietario.</size>");
                y += 188;

                GUI.Label(new Rect(0, y, width, 20), "<b>ESTADO DEL HARDWARE:</b>");
                y += 22;
                GUI.Box(new Rect(0, y, width, 60), GUIContent.none);
                GUI.Label(new Rect(10, y + 6, width - 20, 48),
                    $"• Edge Controller: <color=green>{edgeStatus}</color>\n" +
                    $"• Uplink Cloud: <color=green>{mqttStatus}</color> (Latencia: {telemetryLatency:F0} ms)");
                y += 66;
                break;

            // TAB 5: MÁQUINA DE ESTADOS & ACCIONES
            case 5:
                GUI.Label(new Rect(0, y, width, 22), "<b>ESTADO DE TRANSACCIÓN:</b>");
                y += 24;

                GUI.Box(new Rect(0, y, width, 40), GUIContent.none);
                GUI.Label(new Rect(10, y + 8, width - 20, 24),
                    $"ESTADO: <color=yellow><b>{currentTxState}</b></color>");
                y += 46;

                GUI.Box(new Rect(0, y, width, 70), GUIContent.none);
                GUI.Label(new Rect(10, y + 6, width - 20, 58),
                    $"• Tx ID: <b>{(!string.IsNullOrEmpty(currentTxId) ? currentTxId : "NINGUNA")}</b>\n" +
                    $"• Producto: <b>{(selectedItem != null ? $"{selectedItem.name} ({selectedItem.machineId})" : "NINGUNO")}</b>\n" +
                    $"• Detalle: <color=cyan>{transactionStatusMessage}</color>");
                y += 78;

                GUI.Label(new Rect(0, y, width, 20), "<b>DEMOSTRACIONES INTERACTIVAS:</b>");
                y += 22;

                GUI.color = new Color(0.2f, 1.0f, 0.4f);
                if (GUI.Button(new Rect(0, y, width, 36), "✔ SIMULAR COMPRA CON PROOF OF SERVICE"))
                {
                    if (selectedItem == null)
                    {
                        if (activeMachineType == MachineType.VENDING_SNACKS && vendingSnackItems.Count > 0) selectedItem = vendingSnackItems[0];
                        else if (activeMachineType == MachineType.COLD_BEVERAGES && coldDrinkItems.Count > 0) selectedItem = coldDrinkItems[0];
                        else if (coffeeItems.Count > 0) selectedItem = coffeeItems[0];
                    }
                    if (selectedItem != null) SelectProductToBuy(selectedItem);
                }
                GUI.color = new Color(1.0f, 0.4f, 0.3f);
                if (GUI.Button(new Rect(0, y + 42, width, 36), "⚠ SIMULAR ATASCO & RECONCILIACIÓN REFUND"))
                {
                    StartFailureRecoveryDemo();
                }
                GUI.color = Color.white;
                y += 86;
                break;

            // TAB 6: TELEMETRÍA EN VIVO
            case 6:
                GUI.Label(new Rect(0, y, width, 22), "<b>TELEMETRÍA EN TIEMPO REAL:</b>");
                y += 24;

                GUI.Box(new Rect(0, y, width, 210), GUIContent.none);
                GUI.Label(new Rect(10, y + 6, width - 20, 198),
                    $"• <b>Máquina Seleccionada:</b> {activeMachineId} ({activeMachineType})\n" +
                    $"• <b>VMC Bus Master:</b> <color=cyan>{vmcStatus}</color>\n" +
                    $"• <b>Conectividad IoT:</b> <color=green>{mqttStatus}</color> ({telemetryLatency:F0} ms)\n" +
                    $"• <b>Sensor HC-SR04 (Vending):</b> <color=green>{currentMeasuredDistance:F1} cm</color> {(currentMeasuredDistance < 20f ? "[IMPACTO]" : "[REPOSO]")}\n" +
                    $"• <b>Temp. COOLER-01:</b> <color=cyan>{targetCoolerTemp:F1} °C</color> {(isCoolerDoorOpen ? "[PUERTA ABIERTA]" : "[HERMÉTICO]")}\n" +
                    $"• <b>Caldera COFFEE-01:</b> <color=orange>{coffeeBoilerTemp:F1} °C</color> [PRESIÓN 9.2 BAR]\n" +
                    $"• <b>Proof of Service:</b> {(proofOfServiceBadge != null && proofOfServiceBadge.material == matProofVerified ? "<color=green>VERIFICADO & CAPTURADO</color>" : "<color=gray>STANDBY</color>")}\n" +
                    $"• <b>Salud Global:</b> <color=green>99.4% (Óptimo)</color>");
                y += 218;
                break;

            // TAB 7: GROG AI ENGINE
            case 7:
                GUI.Label(new Rect(0, y, width, 22), "<b>GROG AI ENGINE (INTELIGENCIA MULTI-MÁQUINA):</b>");
                y += 24;

                GUI.Box(new Rect(0, y, width, 180), GUIContent.none);
                GUI.Label(new Rect(10, y + 6, width - 20, 168),
                    "<size=10><b>CAPA DE IA TRANSVERSAL:</b>\n\n" +
                    "• <b>VENDING-01:</b> Motor columna B5 con 82% prob. de atasco por fricción. Alerta emitida.\n" +
                    "• <b>COOLER-01:</b> Compresor al 91% de salud; predice reposición prioritaria de Coca-Cola.\n" +
                    "• <b>COFFEE-01:</b> Sistema de erogación al 94% de eficiencia; descalcificación en 35 días.\n\n" +
                    "<i>Principio de Integridad: La IA recomienda y predice; la liquidación de dinero es estrictamente determinista.</i></size>");
                y += 188;
                break;
        }
    }

    private void DrawPaymentModal()
    {
        GUI.color = new Color(0f, 0f, 0f, 0.6f);
        GUI.DrawTexture(new Rect(0, 0, Screen.width, Screen.height), Texture2D.whiteTexture);
        GUI.color = Color.white;

        paymentModalRect.width = 370;
        paymentModalRect.height = 475;
        paymentModalRect.x = (Screen.width - paymentModalRect.width) / 2f;
        paymentModalRect.y = (Screen.height - paymentModalRect.height) / 2f;

        GUI.Box(paymentModalRect, GUIContent.none);

        float my = paymentModalRect.y + 12;
        float mx = paymentModalRect.x + 16;
        float mw = paymentModalRect.width - 32;

        GUI.Label(new Rect(mx, my, mw, 24), "<b>GROG PAYMENT SERVICE — ABSTRACCIÓN DE PAGO</b>");
        my += 26;

        GUI.Box(new Rect(mx, my, mw, 64), GUIContent.none);
        GUI.Label(new Rect(mx + 8, my + 4, mw - 16, 56),
            $"Producto: <b>{selectedItem.name}</b>\n" +
            $"Precio: <color=yellow><b>Bs {selectedItem.price:F2}</b></color>\n" +
            $"Máquina: <b>{selectedItem.machineId}</b> | Tx: <size=9>{currentTxId}</size>");
        my += 70;

        if (activeQrTexture != null)
        {
            Rect qrRect = new Rect(paymentModalRect.x + (paymentModalRect.width - 140) / 2f, my, 140, 140);
            GUI.DrawTexture(qrRect, activeQrTexture);
            my += 146;
        }

        GUI.Label(new Rect(mx, my, mw, 20), $"Estado: <color=cyan><b>ESPERANDO PAGO (NIVEL 0 / 1)...</b></color>");
        my += 22;

        GUI.color = new Color(0.2f, 1.0f, 0.4f);
        if (GUI.Button(new Rect(mx, my, mw, 34), "✔ PAGO QR DINÁMICO (Nivel 1)"))
        {
            AuthorizePaymentNow();
        }
        my += 38;

        GUI.color = new Color(1.0f, 0.82f, 0.15f);
        if (GUI.Button(new Rect(mx, my, mw, 34), $"💰 INSERTAR MONEDA FÍSICA Bs {selectedItem.price:F2} (Nivel 0)"))
        {
            InsertPhysicalCoin(selectedItem.price);
        }
        my += 38;

        GUI.color = new Color(1.0f, 0.4f, 0.3f);
        if (GUI.Button(new Rect(mx, my, mw, 26), "✖ Cancelar Transacción"))
        {
            CancelCurrentTransaction();
        }
        GUI.color = Color.white;
    }
    #endregion
}
