using System;
using System.Collections;
using System.Collections.Concurrent;
using System.IO;
#if !UNITY_WEBGL
using System.Threading;
#endif
using System.Text;
using System.Text.RegularExpressions;
using UnityEngine;
using UnityEngine.Networking;

/// <summary>
/// Gemelo Digital Vending:
/// 1. Gestiona la comunicación serie virtual (/tmp/ttyUNITY) a 115200 baudios.
/// 2. Conecta con el Backend Orchestrator (POST /transactions/init, /generate-qr, /dispense-result).
/// 3. Renderiza el código QR dinámico recibido en la pantalla 3D de la máquina.
/// 4. Anima el giro de los resortes helicoidales 3D y simula la caída física del producto.
/// 5. Detecta la caída en el receptor inferior y confirma la transacción al backend y al puerto serie.
/// </summary>
public class SerialBridge : MonoBehaviour
{
    [Header("Configuración Puerto Serie")]
    [Tooltip("Ruta del puerto serie virtual")]
    public string portName = "/tmp/ttyUNITY";
    public int baudRate = 115200;

    [Header("Configuración Backend / IoT")]
    [Tooltip("URL del Transaction Orchestrator")]
    public string orchestratorUrl = "http://127.0.0.1:8010";

    [Tooltip("URL pública de la Pasarela de Pago")]
    public string cloudflareGatewayUrl = "https://passivism-sighing-condense.ngrok-free.dev";

    [Tooltip("Identificador único de la máquina")]
    public string machineId = "MACHINE-001";

    [Tooltip("Si está activo, al pulsar un slot se inicia el flujo completo con QR")]
    public bool enableBackendQrFlow = true;

    [Tooltip("Sondear transacciones pagadas externamente (web/móvil)")]
    public bool pollExternalTransactions = true;

    [Tooltip("Mostrar panel GUI legado en pantalla (desactivado por defecto para evitar colisión visual)")]
    public bool showLegacyGui = false;

    [Header("Referencias de la Máquina 3D")]
    public Transform[] slotSpawnPoints = new Transform[9];
    public Transform[] spiralTransforms = new Transform[9];
    public TextMesh[] slotPriceLabels = new TextMesh[9];
    public Collider dropReceiverCollider;
    public TextMesh displayScreen;
    public Renderer qrDisplayRenderer;
    public Texture2D qrIdleTexture;
    public GameObject productPrefab;

    [Header("Catálogo de Productos por Ranura")]
    public SlotProduct[] catalog = new SlotProduct[9]
    {
        new SlotProduct { slotNumber = 1, slotCode = "A1", productName = "Ronditas", sku = "SKU-MACHINE-001-A1", price = 2.50f },
        new SlotProduct { slotNumber = 2, slotCode = "B5", productName = "Sprite Zero", sku = "SKU-MACHINE-001-B5", price = 7.00f },
        new SlotProduct { slotNumber = 3, slotCode = "A2", productName = "Chocmam", sku = "SKU-MACHINE-001-A2", price = 3.00f },
        new SlotProduct { slotNumber = 4, slotCode = "A3", productName = "Gomitas Rosadas", sku = "SKU-MACHINE-001-A3", price = 3.50f },
        new SlotProduct { slotNumber = 5, slotCode = "A7", productName = "Gomitas Azules", sku = "SKU-MACHINE-001-A7", price = 3.50f },
        new SlotProduct { slotNumber = 6, slotCode = "C1", productName = "Chocman", sku = "SKU-MACHINE-001-C1", price = 4.50f },
        new SlotProduct { slotNumber = 7, slotCode = "C2", productName = "Oreo", sku = "SKU-MACHINE-001-C2", price = 6.00f },
        new SlotProduct { slotNumber = 8, slotCode = "C3", productName = "Chocman Max", sku = "SKU-MACHINE-001-C3", price = 6.00f },
        new SlotProduct { slotNumber = 9, slotCode = "C7", productName = "Chips Papas", sku = "CHIPS-002", price = 6.00f }
    };

    [Header("Colores de Productos")]
    public Color[] productColors = new Color[]
    {
        new Color(0.9f, 0.2f, 0.2f), // Rojo
        new Color(0.2f, 0.6f, 1.0f), // Azul
        new Color(0.2f, 0.8f, 0.3f), // Verde
        new Color(1.0f, 0.7f, 0.1f), // Naranja
        new Color(0.7f, 0.2f, 0.9f), // Púrpura
        new Color(1.0f, 0.9f, 0.2f), // Amarillo
        new Color(0.1f, 0.8f, 0.8f), // Cyan
        new Color(0.9f, 0.4f, 0.7f), // Rosa
        new Color(0.8f, 0.5f, 0.2f)  // Marrón
    };

    // Estado de la Transacción en Curso
    [Header("Estado Transacción Actual")]
    public string currentTxId = "";
    public string currentTxState = "IDLE";
    public int currentSlot = -1;
    public bool isWaitingForPayment = false;
    public bool isDispensing = false;

    [Header("Monitoreo en Pantalla (En Vivo)")]
    public string currentDisplayText = "SELECCIONE: 1-9";
    public string sensorStatusText = "EN REPOSO (Bandeja Vacía)";
    public Color sensorStatusColor = new Color(0.5f, 0.5f, 0.5f);
    public Texture2D activeQrTexture = null;
    public string lastLogMessage = "Gemelo Digital listo.";

    // Manejador SerialPort y Flujo Linux
#if !UNITY_WEBGL
    private FileStream linuxStream;
    private Thread linuxReadThread;
#endif
    private StringBuilder rxBuffer = new StringBuilder();
    private volatile bool isRunning = false;
    private ConcurrentQueue<string> incomingQueue = new ConcurrentQueue<string>();
    private bool isPortOpen = false;
    private bool isUsingLinuxStream = false;

    public bool IsPortOpen => isPortOpen;
    public bool IsUsingLinuxStream => isUsingLinuxStream;

    // Coroutines de Transacción
    private Coroutine activeTxCoroutine;
    private Coroutine activePollCoroutine;
    private Coroutine externalOrdersCoroutine;

    // Cache de textura QR por defecto
    private Texture2D defaultIdleTexture;

    [System.Serializable]
    public class SlotProduct
    {
        public int slotNumber;
        public string slotCode;
        public string productName;
        public string sku;
        public float price;
    }

    [System.Serializable]
    private class VendingJsonCommand
    {
        public string command;
        public string action;
        public int slot;
        public int motor;
    }

    [System.Serializable]
    private class InitTxResponse
    {
        public string id;
        public string tx_id;
        public string machine_id;
        public string product_id;
        public float amount;
        public string state;
    }

    [System.Serializable]
    private class QrResponse
    {
        public string tx_id;
        public string qr_data;
        public string qr_image;
        public string state;
    }

    [System.Serializable]
    private class TxStatusResponse
    {
        public string tx_id;
        public string state;
        public string product_id;
        public float amount;
    }

    [System.Serializable]
    private class NextPaidItem
    {
        public string tx_id;
        public string product_id;
    }

    [System.Serializable]
    private class NextPaidResponse
    {
        public NextPaidItem item;
    }

    private void Start()
    {
#if UNITY_WEBGL
        if (string.IsNullOrEmpty(cloudflareGatewayUrl) || cloudflareGatewayUrl.Contains("trycloudflare.com"))
        {
            cloudflareGatewayUrl = "https://passivism-sighing-condense.ngrok-free.dev";
        }
        orchestratorUrl = $"{cloudflareGatewayUrl.TrimEnd('/')}/p/8010";
#else
        if (string.IsNullOrEmpty(orchestratorUrl) || orchestratorUrl.Contains("trycloudflare.com"))
        {
            orchestratorUrl = "http://127.0.0.1:8010";
        }
        if (string.IsNullOrEmpty(cloudflareGatewayUrl) || cloudflareGatewayUrl.Contains("trycloudflare.com"))
        {
            cloudflareGatewayUrl = "https://passivism-sighing-condense.ngrok-free.dev";
        }
#endif

        UpdateDisplay("SELECCIONE: 1-9");
        CreateDefaultIdleTexture();
        ResetQrDisplay();
        OpenSerialPort();

        if (pollExternalTransactions)
        {
            externalOrdersCoroutine = StartCoroutine(PollExternalOrdersWorker());
        }
    }

    private void CreateDefaultIdleTexture()
    {
        if (defaultIdleTexture != null) return;
        defaultIdleTexture = new Texture2D(128, 128, TextureFormat.RGBA32, false);
        Color bgColor = new Color(0.05f, 0.08f, 0.12f, 1f);
        Color frameColor = new Color(0.15f, 0.45f, 0.75f, 1f);
        for (int y = 0; y < 128; y++)
        {
            for (int x = 0; x < 128; x++)
            {
                bool isBorder = (x < 4 || x > 123 || y < 4 || y > 123);
                defaultIdleTexture.SetPixel(x, y, isBorder ? frameColor : bgColor);
            }
        }
        defaultIdleTexture.Apply();
    }

    public void ResetQrDisplay()
    {
        activeQrTexture = null;
        if (qrDisplayRenderer != null)
        {
            Texture2D idle = qrIdleTexture != null ? qrIdleTexture : defaultIdleTexture;
            qrDisplayRenderer.material.mainTexture = idle;
        }
    }

    public void SetQrTexture(Texture2D qrTex)
    {
        if (qrDisplayRenderer != null && qrTex != null)
        {
            qrDisplayRenderer.material.mainTexture = qrTex;
        }
    }

    #region Comunicación Serie y Flujo Nativo Linux
    public void OpenSerialPort()
    {
#if !UNITY_WEBGL
        OpenLinuxNativeStream();
#else
        isPortOpen = false;
        Debug.Log("[SerialBridge] WebGL detectado: Puerto serie físico deshabilitado. Modo Cloud HTTP/API activo.");
#endif
    }

#if !UNITY_WEBGL
    private void OpenLinuxNativeStream()
    {
        try
        {
            if (!File.Exists(portName))
            {
                LogPortUnavailable();
                return;
            }

            linuxStream = new FileStream(portName, FileMode.Open, FileAccess.ReadWrite, FileShare.ReadWrite);
            isRunning = true;
            isPortOpen = true;
            isUsingLinuxStream = true;

            linuxReadThread = new Thread(LinuxReadWorker);
            linuxReadThread.IsBackground = true;
            linuxReadThread.Start();

            Debug.Log($"[SerialBridge] Adaptador nativo Linux conectado a {portName}!");
        }
        catch (Exception ex)
        {
            isPortOpen = false;
            LogPortUnavailable(ex.Message);
        }
    }

    private void LinuxReadWorker()
    {
        byte[] buffer = new byte[1024];
        StringBuilder lineAccumulator = new StringBuilder();

        while (isRunning && linuxStream != null)
        {
            try
            {
                int bytesRead = linuxStream.Read(buffer, 0, buffer.Length);
                if (bytesRead > 0)
                {
                    string text = Encoding.UTF8.GetString(buffer, 0, bytesRead);
                    lineAccumulator.Append(text);

                    string content = lineAccumulator.ToString();
                    int newlineIdx;
                    while ((newlineIdx = content.IndexOf('\n')) >= 0)
                    {
                        string line = content.Substring(0, newlineIdx).Trim();
                        content = content.Substring(newlineIdx + 1);
                        if (!string.IsNullOrEmpty(line))
                        {
                            incomingQueue.Enqueue(line);
                        }
                    }
                    lineAccumulator.Clear();
                    lineAccumulator.Append(content);
                }
                else
                {
                    Thread.Sleep(10);
                }
            }
            catch (ThreadAbortException) { break; }
            catch (Exception) { Thread.Sleep(50); }
        }
    }
#endif

    private void LogPortUnavailable(string detail = "")
    {
        isPortOpen = false;
        Debug.LogWarning($"[SerialBridge] Puerto serie virtual no disponible ({portName}). {detail}\n" +
                         "Para conectar con hardware externo ejecuta:\n" +
                         "socat -d -d pty,raw,echo=0,link=/tmp/ttyUNITY pty,raw,echo=0,link=/tmp/ttyCLI");
    }

    public void SendSerialMessage(string message)
    {
#if !UNITY_WEBGL
        if (isUsingLinuxStream && linuxStream != null)
        {
            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(message);
                linuxStream.Write(bytes, 0, bytes.Length);
                linuxStream.Flush();
                Debug.Log($"[SerialBridge] TX (Linux) -> {message.TrimEnd()}");
                return;
            }
            catch (Exception ex)
            {
                Debug.LogError($"[SerialBridge] Error enviando por stream Linux: {ex.Message}");
            }
        }
#endif

        Debug.Log($"[SerialBridge] (Simulado) TX -> {message.TrimEnd()}");
    }
    #endregion

    private void Update()
    {
        // 1. Procesar cola de comandos serie
        while (incomingQueue.TryDequeue(out string linuxCommand))
        {
            ProcessCommand(linuxCommand);
        }

        // 2. Detección de clics sobre los botones 3D del teclado frontal
        CheckMouseClicks();

        // 3. Soporte para teclas numéricas 1 a 9 y teclado numérico
        CheckKeyboardInputs();
    }

    private void CheckMouseClicks()
    {
        if (Input.GetMouseButtonDown(0))
        {
            Camera cam = Camera.main;
            if (cam != null)
            {
                Ray ray = cam.ScreenPointToRay(Input.mousePosition);
                if (Physics.Raycast(ray, out RaycastHit hit, 20f))
                {
                    VendingButton btn = hit.collider.GetComponent<VendingButton>();
                    if (btn != null)
                    {
                        btn.Press();
                        Debug.Log($"[SerialBridge] Botón 3D presionado en {btn.targetMachineId} - Slot {btn.slotNumber}");

                        MDBArchitectureManager archMgr = GetComponent<MDBArchitectureManager>();
                        if (archMgr != null)
                        {
                            archMgr.SelectProductByMachineAndSlot(btn.targetMachineId, btn.slotNumber, btn.itemId);
                        }
                        else
                        {
                            OnSlotSelected(btn.slotNumber);
                        }
                    }
                }
            }
        }
    }

    private void CheckKeyboardInputs()
    {
        for (int i = 1; i <= 9; i++)
        {
            KeyCode key = KeyCode.Alpha0 + i;
            KeyCode keyPad = KeyCode.Keypad0 + i;
            if (Input.GetKeyDown(key) || Input.GetKeyDown(keyPad))
            {
                Debug.Log($"[SerialBridge] Tecla {i} presionada en el teclado");
                OnSlotSelected(i);
            }
        }

        // Cancelar transacción con tecla Escape o '*'
        if (Input.GetKeyDown(KeyCode.Escape) || Input.GetKeyDown(KeyCode.KeypadMultiply))
        {
            if (isWaitingForPayment)
            {
                Debug.Log("[SerialBridge] Transacción cancelada por el usuario");
                CancelTransaction("CANCELADO POR USUARIO");
            }
        }
    }

    /// <summary>
    /// Punto de entrada cuando se selecciona una ranura (1 al 9).
    /// </summary>
    public void OnSlotSelected(int slotNumber)
    {
        if (isDispensing)
        {
            Debug.LogWarning("[SerialBridge] Máquina ocupada dispensando producto.");
            return;
        }

        if (slotNumber < 1 || slotNumber > 9)
        {
            Debug.LogWarning($"[SerialBridge] Ranura inválida: {slotNumber}");
            return;
        }

        // Si MDBArchitectureManager está en escena, sincronizar con su catálogo e iniciar el flujo de selección primero
        MDBArchitectureManager archMgr = GetComponent<MDBArchitectureManager>();
        if (archMgr != null && archMgr.vendingSnackItems != null && archMgr.vendingSnackItems.Count >= slotNumber)
        {
            var item = archMgr.vendingSnackItems[slotNumber - 1];
            archMgr.SelectProductToBuy(item);
            return;
        }

        if (enableBackendQrFlow)
        {
            StartQrTransactionFlow(slotNumber);
        }
        else
        {
            DispenseProduct(slotNumber);
        }
    }

    #region Flujo Completo Backend & Pago con QR
    public void StartQrTransactionFlow(int slotNumber)
    {
        if (activeTxCoroutine != null)
        {
            StopCoroutine(activeTxCoroutine);
        }
        if (activePollCoroutine != null)
        {
            StopCoroutine(activePollCoroutine);
        }

        activeTxCoroutine = StartCoroutine(QrTransactionFlowWorker(slotNumber));
    }

    private IEnumerator QrTransactionFlowWorker(int slotNumber)
    {
        currentSlot = slotNumber;
        SlotProduct product = GetSlotProduct(slotNumber);

        isWaitingForPayment = false;
        currentTxState = "INICIANDO";
        UpdateDisplay($"CONECTANDO #{slotNumber}...");
        ResetQrDisplay();

        // 1. POST /api/v1/transactions/init
        string initUrl = orchestratorUrl.TrimEnd('/') + "/api/v1/transactions/init";
        string initPayload = $"{{\"machine_id\":\"{machineId}\",\"product_id\":\"{product.sku}\",\"amount\":{product.price.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)},\"payment_method\":\"QR\"}}";

        Debug.Log($"[SerialBridge] Inicializando TX: POST {initUrl} -> {initPayload}");

        using (UnityWebRequest initReq = new UnityWebRequest(initUrl, "POST"))
        {
            byte[] bodyRaw = Encoding.UTF8.GetBytes(initPayload);
            initReq.uploadHandler = new UploadHandlerRaw(bodyRaw);
            initReq.downloadHandler = new DownloadHandlerBuffer();
            initReq.SetRequestHeader("Content-Type", "application/json");
            initReq.SetRequestHeader("ngrok-skip-browser-warning", "1");

            yield return initReq.SendWebRequest();

            if (initReq.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"[SerialBridge] Error en /init: {initReq.error} - {initReq.downloadHandler?.text}");
                UpdateDisplay("ERROR CONEXION");
                currentTxState = "ERROR";
                yield return new WaitForSeconds(2.5f);
                UpdateDisplay("SELECCIONE: 1-9");
                yield break;
            }

            string initJson = initReq.downloadHandler.text;
            Debug.Log($"[SerialBridge] /init respuesta: {initJson}");
            InitTxResponse initData = JsonUtility.FromJson<InitTxResponse>(initJson);
            currentTxId = !string.IsNullOrEmpty(initData.tx_id) ? initData.tx_id : initData.id;
        }

        if (string.IsNullOrEmpty(currentTxId))
        {
            Debug.LogError("[SerialBridge] No se recibió tx_id del orquestador");
            UpdateDisplay("ERROR TX ID");
            yield return new WaitForSeconds(2.5f);
            UpdateDisplay("SELECCIONE: 1-9");
            yield break;
        }

        // 2. POST /api/v1/transactions/{tx_id}/generate-qr
        string qrUrl = $"{orchestratorUrl.TrimEnd('/')}/api/v1/transactions/{currentTxId}/generate-qr";
        Debug.Log($"[SerialBridge] Generando QR: POST {qrUrl}");

        using (UnityWebRequest qrReq = new UnityWebRequest(qrUrl, "POST"))
        {
            byte[] emptyBody = Encoding.UTF8.GetBytes("{}");
            qrReq.uploadHandler = new UploadHandlerRaw(emptyBody);
            qrReq.downloadHandler = new DownloadHandlerBuffer();
            qrReq.SetRequestHeader("Content-Type", "application/json");
            qrReq.SetRequestHeader("ngrok-skip-browser-warning", "1");

            yield return qrReq.SendWebRequest();

            if (qrReq.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"[SerialBridge] Error generando QR: {qrReq.error}");
                UpdateDisplay("ERROR AL CREAR QR");
                yield return new WaitForSeconds(2.5f);
                UpdateDisplay("SELECCIONE: 1-9");
                yield break;
            }

            string qrJson = qrReq.downloadHandler.text;
            QrResponse qrData = JsonUtility.FromJson<QrResponse>(qrJson);

            if (!string.IsNullOrEmpty(qrData.qr_image))
            {
                RenderBase64QrToTexture(qrData.qr_image);
            }
            else
            {
                Debug.LogWarning("[SerialBridge] qr_image vino vacío del backend");
            }
        }

        // 3. Mostrar precio y estado de pago en el LCD
        isWaitingForPayment = true;
        currentTxState = "ESPERANDO_PAGO";
        UpdateDisplay($"PAGAR: Bs. {product.price:F2}");
        Debug.Log($"[SerialBridge] Código QR generado y renderizado en pantalla 3D. Esperando pago para TX {currentTxId}...");

        // 4. Iniciar sondeo del estado de pago
        activePollCoroutine = StartCoroutine(PollTransactionPaymentStatus(currentTxId, slotNumber));
    }

    private void RenderBase64QrToTexture(string base64Image)
    {
        try
        {
            string cleanB64 = base64Image;
            if (cleanB64.Contains(","))
            {
                cleanB64 = cleanB64.Substring(cleanB64.IndexOf(",") + 1);
            }

            byte[] imageBytes = Convert.FromBase64String(cleanB64);
            Texture2D qrTexture = new Texture2D(256, 256, TextureFormat.RGBA32, false);
            qrTexture.filterMode = FilterMode.Point; // Máxima nitidez sin borrosidad
            qrTexture.wrapMode = TextureWrapMode.Clamp;
            qrTexture.LoadImage(imageBytes);

            activeQrTexture = qrTexture;
            SetQrTexture(qrTexture);
            lastLogMessage = $"QR generado para #{currentSlot} ({GetSlotProduct(currentSlot).productName}). Esperando pago...";
            Debug.Log("[SerialBridge] ¡QR cargado exitosamente en la pantalla 3D!");
        }
        catch (Exception ex)
        {
            Debug.LogError($"[SerialBridge] Error decodificando imagen QR base64: {ex.Message}");
        }
    }

    private IEnumerator PollTransactionPaymentStatus(string txId, int slotNumber)
    {
        string statusUrl = $"{orchestratorUrl.TrimEnd('/')}/api/v1/transactions/{txId}";
        float pollTimeoutSeconds = 120f;
        float elapsed = 0f;

        while (isWaitingForPayment && elapsed < pollTimeoutSeconds)
        {
            yield return new WaitForSeconds(1.2f);
            elapsed += 1.2f;

            using (UnityWebRequest pollReq = UnityWebRequest.Get(statusUrl))
            {
                pollReq.SetRequestHeader("ngrok-skip-browser-warning", "1");
                yield return pollReq.SendWebRequest();

                if (pollReq.result == UnityWebRequest.Result.Success)
                {
                    string json = pollReq.downloadHandler.text;
                    TxStatusResponse status = JsonUtility.FromJson<TxStatusResponse>(json);

                    if (status != null && !string.IsNullOrEmpty(status.state))
                    {
                        currentTxState = status.state;

                        // Estado de pago confirmado listo para dispensar
                        if (status.state == "PAID_PENDING_DISPENSE" || status.state == "PAID")
                        {
                            lastLogMessage = $"¡Pago confirmado en Internet! Girando motor #{slotNumber}...";
                            Debug.Log($"[SerialBridge] ¡PAGO CONFIRMADO por el backend para TX {txId}! Procediendo al dispensado...");
                            isWaitingForPayment = false;
                            ExecuteDispense(slotNumber, txId);
                            yield break;
                        }
                        else if (status.state == "CANCELLED" || status.state == "REFUNDED" || status.state == "ERROR")
                        {
                            CancelTransaction($"ESTADO: {status.state}");
                            yield break;
                        }
                    }
                }
            }
        }

        if (isWaitingForPayment)
        {
            CancelTransaction("TIEMPO AGOTADO");
        }
    }

    /// <summary>
    /// Simula el pago de la transacción actual desde Unity para pruebas rápidas
    /// </summary>
    public void SimulatePaymentNow()
    {
        if (string.IsNullOrEmpty(currentTxId) || !isWaitingForPayment)
        {
            Debug.LogWarning("[SerialBridge] No hay transacción activa esperando pago.");
            return;
        }

        StartCoroutine(SimulatePaymentWorker(currentTxId));
    }

    private IEnumerator SimulatePaymentWorker(string txId)
    {
        UpdateDisplay("SIMULANDO PAGO...");
        string confirmUrl = $"{orchestratorUrl.TrimEnd('/')}/api/v1/transactions/{txId}/payment-confirmed";
        string payload = "{\"reference\":\"SIMULATED_TEST_PAYMENT\"}";

        using (UnityWebRequest req = new UnityWebRequest(confirmUrl, "POST"))
        {
            byte[] body = Encoding.UTF8.GetBytes(payload);
            req.uploadHandler = new UploadHandlerRaw(body);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            req.SetRequestHeader("ngrok-skip-browser-warning", "1");

            yield return req.SendWebRequest();

            if (req.result == UnityWebRequest.Result.Success)
            {
                Debug.Log($"[SerialBridge] Pago simulado confirmado para TX {txId}!");
            }
            else
            {
                Debug.LogError($"[SerialBridge] Error simulando pago: {req.error}");
            }
        }
    }

    public void CancelTransaction(string reason = "CANCELADO")
    {
        isWaitingForPayment = false;
        currentTxState = "CANCELADO";
        UpdateDisplay(reason);
        ResetQrDisplay();

        if (activePollCoroutine != null)
        {
            StopCoroutine(activePollCoroutine);
            activePollCoroutine = null;
        }

        StartCoroutine(ResetDisplayAfterDelay(2.5f));
    }

    private IEnumerator PollExternalOrdersWorker()
    {
        string nextPaidUrl = $"{orchestratorUrl.TrimEnd('/')}/api/v1/machines/{machineId}/next-paid";

        while (true)
        {
            yield return new WaitForSeconds(2.0f);

            // Solo sondear si la máquina está libre y en reposo
            if (isWaitingForPayment || isDispensing) continue;

            using (UnityWebRequest req = UnityWebRequest.Get(nextPaidUrl))
            {
                req.SetRequestHeader("ngrok-skip-browser-warning", "1");
                yield return req.SendWebRequest();

                if (req.result == UnityWebRequest.Result.Success)
                {
                    string json = req.downloadHandler.text;
                    if (json.Contains("\"item\"") && !json.Contains("\"item\":null"))
                    {
                        NextPaidResponse res = JsonUtility.FromJson<NextPaidResponse>(json);
                        if (res != null && res.item != null && !string.IsNullOrEmpty(res.item.tx_id))
                        {
                            int targetSlot = FindSlotBySku(res.item.product_id);
                            Debug.Log($"[SerialBridge] ¡Orden Externa Recibida! TX: {res.item.tx_id} | Producto: {res.item.product_id} -> Ranura {targetSlot}");
                            ExecuteDispense(targetSlot, res.item.tx_id);
                        }
                    }
                }
            }
        }
    }

    private int FindSlotBySku(string skuOrCode)
    {
        if (string.IsNullOrEmpty(skuOrCode)) return 9;

        for (int i = 0; i < catalog.Length; i++)
        {
            if (string.Equals(catalog[i].sku, skuOrCode, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(catalog[i].slotCode, skuOrCode, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(catalog[i].productName, skuOrCode, StringComparison.OrdinalIgnoreCase))
            {
                return catalog[i].slotNumber;
            }
        }
        return 9; // Slot por defecto
    }

    private SlotProduct GetSlotProduct(int slotNumber)
    {
        int index = Mathf.Clamp(slotNumber - 1, 0, catalog.Length - 1);
        return catalog[index];
    }
    #endregion

    #region Dispensado Físico y Sensores
    private void ExecuteDispense(int slotNumber, string txId)
    {
        currentSlot = slotNumber;
        currentTxId = txId;
        isDispensing = true;
        currentTxState = "DISPENSANDO";

        DispenseProduct(slotNumber);
    }

    public void DispenseProduct(int slotNumber)
    {
        int slotIndex = slotNumber - 1;
        UpdateDisplay($"MOTOR #{slotNumber} ACTIVO");

        // 1. Animar el giro del resorte helicoidal 3D
        if (spiralTransforms != null && slotIndex >= 0 && slotIndex < spiralTransforms.Length && spiralTransforms[slotIndex] != null)
        {
            StartCoroutine(AnimateSpiralCoil(spiralTransforms[slotIndex]));
        }

        // 2. Instanciar el producto
        Vector3 spawnPosition;
        if (slotSpawnPoints != null && slotIndex >= 0 && slotIndex < slotSpawnPoints.Length && slotSpawnPoints[slotIndex] != null)
        {
            spawnPosition = slotSpawnPoints[slotIndex].position;
        }
        else
        {
            spawnPosition = transform.position + new Vector3(0, 2.5f, 0);
        }

        GameObject product;
        if (productPrefab != null)
        {
            product = Instantiate(productPrefab, spawnPosition, Quaternion.identity);
        }
        else
        {
            product = GameObject.CreatePrimitive(PrimitiveType.Cube);
            product.name = $"Producto_Ranura_{slotNumber}_{Time.frameCount}";
            product.transform.position = spawnPosition;
            product.transform.localScale = new Vector3(0.20f, 0.20f, 0.20f);

            Renderer rend = product.GetComponent<Renderer>();
            if (rend != null)
            {
                Color chosenColor = productColors[(slotNumber - 1) % productColors.Length];
                rend.material.color = chosenColor;
            }
        }

        Rigidbody rb = product.GetComponent<Rigidbody>();
        if (rb == null)
        {
            rb = product.AddComponent<Rigidbody>();
        }
        rb.mass = 0.5f;
        rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;

        // Leve empuje hacia adelante simulando la expulsión del espiral
        rb.linearVelocity = new Vector3(0, -0.05f, -0.5f);

        VendingProduct tracker = product.AddComponent<VendingProduct>();
        tracker.Setup(this, slotNumber);

        Debug.Log($"[SerialBridge] Resorte {slotNumber} girando 360°. Producto en caída.");
    }

    private IEnumerator AnimateSpiralCoil(Transform spiral)
    {
        float duration = 0.85f;
        float elapsed = 0f;
        Quaternion startRot = spiral.localRotation;

        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            float progress = Mathf.Clamp01(elapsed / duration);
            float angle = Mathf.Lerp(0f, 360f, progress);
            spiral.localRotation = startRot * Quaternion.Euler(0f, 0f, -angle);
            yield return null;
        }

        spiral.localRotation = startRot;
    }

    /// <summary>
    /// Llamado cuando el producto cae en el receptor inferior (sensor de caída trigger).
    /// </summary>
    public void OnProductDropped(GameObject product)
    {
        if (product == null) return;

        VendingProduct tracker = product.GetComponent<VendingProduct>();
        if (tracker != null && tracker.IsProcessed) return;
        if (tracker != null) tracker.IsProcessed = true;

        UpdateDisplay("PRODUCTO ENTREGADO!");
        ResetQrDisplay();

        sensorStatusText = $"¡IMPACTO DETECTADO! ({product.name})";
        sensorStatusColor = Color.green;
        lastLogMessage = $"Sensor activado: Producto #{currentSlot} entregado con éxito.";

        Debug.Log($"[SerialBridge] ¡CONFIRMACIÓN FÍSICA!: Producto '{product.name}' cayó en el receptor inferior.");

        // 1. Enviar confirmación al puerto serie virtual
        SendSerialMessage("PRODUCTO_CAIDO\n");

        // 2. Reportar al Backend Orchestrator si hay transacción activa
        if (!string.IsNullOrEmpty(currentTxId))
        {
            StartCoroutine(ReportDispenseResultWorker(currentTxId, true));
        }

        isDispensing = false;
        isWaitingForPayment = false;
        currentTxState = "COMPLETED";

        StartCoroutine(ResetDisplayAfterDelay(3.5f));
        Destroy(product, 4.0f);
    }

    private IEnumerator ReportDispenseResultWorker(string txId, bool success)
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

            yield return req.SendWebRequest();

            if (req.result == UnityWebRequest.Result.Success)
            {
                Debug.Log($"[SerialBridge] Dispense-result reportado exitosamente al backend para TX {txId}!");
            }
            else
            {
                Debug.LogWarning($"[SerialBridge] Error reportando dispense-result: {req.error}");
            }
        }

        currentTxId = "";
    }

    private IEnumerator ResetDisplayAfterDelay(float delay)
    {
        yield return new WaitForSeconds(delay);
        if (!isWaitingForPayment && !isDispensing)
        {
            sensorStatusText = "EN REPOSO (Bandeja Vacía)";
            sensorStatusColor = new Color(0.5f, 0.5f, 0.5f);
            UpdateDisplay("SELECCIONE: 1-9");
            currentTxState = "IDLE";
        }
    }

    private void UpdateDisplay(string text)
    {
        currentDisplayText = text;
        if (displayScreen != null)
        {
            displayScreen.text = text;
        }
    }
    #endregion

    #region Procesamiento de Comandos
    public void ProcessCommand(string commandString)
    {
        string raw = commandString.Trim();
        Debug.Log($"[SerialBridge] Comando recibido: '{raw}'");

        if (raw.StartsWith("{") && raw.EndsWith("}"))
        {
            try
            {
                VendingJsonCommand jsonObj = JsonUtility.FromJson<VendingJsonCommand>(raw);
                if (jsonObj != null)
                {
                    int targetSlot = 0;
                    if (jsonObj.slot > 0) targetSlot = jsonObj.slot;
                    else if (jsonObj.motor > 0) targetSlot = jsonObj.motor;
                    else if (!string.IsNullOrEmpty(jsonObj.command)) targetSlot = ExtractSlotNumber(jsonObj.command);
                    else if (!string.IsNullOrEmpty(jsonObj.action)) targetSlot = ExtractSlotNumber(jsonObj.action);

                    if (targetSlot >= 1 && targetSlot <= 9)
                    {
                        OnSlotSelected(targetSlot);
                        return;
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.LogWarning($"[SerialBridge] Falló parseo JSON ('{raw}'): {ex.Message}");
            }
        }

        int slotNum = ExtractSlotNumber(raw);
        if (slotNum >= 1 && slotNum <= 9)
        {
            OnSlotSelected(slotNum);
            return;
        }

        Debug.LogWarning($"[SerialBridge] Comando no reconocido: '{raw}'");
    }

    private int ExtractSlotNumber(string text)
    {
        if (string.IsNullOrEmpty(text)) return -1;

        Match match = Regex.Match(text.ToUpper(), @"(?:GIRAR_)?MOTOR[_\s:]?([1-9])");
        if (match.Success && int.TryParse(match.Groups[1].Value, out int slot))
        {
            return slot;
        }

        if (int.TryParse(text.Trim(), out int directNum) && directNum >= 1 && directNum <= 9)
        {
            return directNum;
        }

        return -1;
    }
    #endregion

    #region Interfaz OnGUI en Pantalla
    private void OnGUI()
    {
        if (!showLegacyGui) return;

        GUILayout.BeginArea(new Rect(15, 15, 340, 480), GUI.skin.box);
        GUILayout.Label("<b>GEMELO VENDING 3D + BACKEND</b>", GUI.skin.label);
        GUILayout.Space(4);

        // Estado del backend público en Internet
        GUILayout.Label("<b>URL Backend (Público Internet):</b>");
        orchestratorUrl = GUILayout.TextField(orchestratorUrl);
        GUILayout.Label($"<b>Máquina:</b> {machineId} | <b>Estado:</b> <color=cyan>{currentTxState}</color>");

        if (!string.IsNullOrEmpty(currentTxId))
        {
            GUILayout.Label($"<b>TX ID:</b> {currentTxId.Substring(0, Mathf.Min(16, currentTxId.Length))}...");
        }

        GUILayout.Space(6);
        enableBackendQrFlow = GUILayout.Toggle(enableBackendQrFlow, " Flujo Completo con Pago QR");

        // 1. Monitor LCD en Vivo (Refleja la pantalla 3D en la GUI)
        GUI.color = new Color(0.2f, 1.0f, 0.4f);
        GUILayout.Box($"<size=15><b>[ PANTALLA LCD 3D ]</b>\n» {currentDisplayText}</size>", GUILayout.Height(46));
        GUI.color = Color.white;

        // 2. Monitor del Sensor de Caída Físico
        GUI.color = sensorStatusColor;
        GUILayout.Box($"<b>[ SENSOR BANDEJA ]:</b> {sensorStatusText}", GUILayout.Height(26));
        GUI.color = Color.white;

        // 3. Si hay un QR activo, mostrarlo en pantalla grande
        if (isWaitingForPayment && activeQrTexture != null)
        {
            GUILayout.Space(4);
            GUILayout.Label("<b>Código QR Generado (SimuPay):</b>");
            Rect qrRect = GUILayoutUtility.GetRect(150, 150, GUILayout.ExpandWidth(false));
            GUI.DrawTexture(new Rect(qrRect.x + (qrRect.width - 140) / 2, qrRect.y, 140, 140), activeQrTexture, ScaleMode.ScaleToFit);
            GUILayout.Space(4);
        }

        GUILayout.Space(4);
        if (isWaitingForPayment)
        {
            GUI.color = Color.green;
            if (GUILayout.Button("✔ SIMULAR PAGO AHORA (SimuPay)", GUILayout.Height(38)))
            {
                SimulatePaymentNow();
            }

            GUI.color = Color.red;
            if (GUILayout.Button("✖ Cancelar Transacción", GUILayout.Height(26)))
            {
                CancelTransaction("CANCELADO");
            }
            GUI.color = Color.white;

            GUILayout.Space(4);
            GUILayout.Label("<size=10><i>Escanea el QR en la pantalla de la máquina 3D o usa el botón verde.</i></size>");
        }
        else
        {
            GUILayout.Label("<b>Seleccionar Producto para Probar:</b>");
            GUILayout.BeginHorizontal();
            for (int i = 1; i <= 3; i++)
            {
                SlotProduct p = GetSlotProduct(i);
                if (GUILayout.Button($"#{i} {p.productName}\nBs.{p.price:F2}", GUILayout.Height(38)))
                {
                    OnSlotSelected(i);
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.BeginHorizontal();
            for (int i = 4; i <= 6; i++)
            {
                SlotProduct p = GetSlotProduct(i);
                if (GUILayout.Button($"#{i} {p.productName}\nBs.{p.price:F2}", GUILayout.Height(38)))
                {
                    OnSlotSelected(i);
                }
            }
            GUILayout.EndHorizontal();

            GUILayout.BeginHorizontal();
            for (int i = 7; i <= 9; i++)
            {
                SlotProduct p = GetSlotProduct(i);
                if (GUILayout.Button($"#{i} {p.productName}\nBs.{p.price:F2}", GUILayout.Height(38)))
                {
                    OnSlotSelected(i);
                }
            }
            GUILayout.EndHorizontal();
        }

        GUILayout.Space(6);
        GUILayout.Label($"<b>Último Evento:</b> <color=yellow>{lastLogMessage}</color>");
        GUILayout.Label("<b>Pasarela Cloudflare:</b> " + cloudflareGatewayUrl);

        GUILayout.EndArea();
    }
    #endregion

    private void CloseSerialPort()
    {
        isRunning = false;

#if !UNITY_WEBGL
        if (linuxReadThread != null && linuxReadThread.IsAlive)
        {
            try { linuxReadThread.Abort(); } catch { }
            linuxReadThread = null;
        }

        if (linuxStream != null)
        {
            try { linuxStream.Close(); linuxStream.Dispose(); } catch { }
            linuxStream = null;
        }
#endif

        isPortOpen = false;
        isUsingLinuxStream = false;
    }

    private void OnDestroy()
    {
        CloseSerialPort();
    }

    private void OnApplicationQuit()
    {
        CloseSerialPort();
    }
}

/// <summary>
/// Componente para botones 3D interactivos del teclado frontal o botones de selección de las máquinas.
/// </summary>
public class VendingButton : MonoBehaviour
{
    public string targetMachineId = "VENDING-01";
    public string itemId = "";
    public int slotNumber = 1;
    private bool isPressing = false;

    public void Press()
    {
        if (!isPressing)
        {
            StartCoroutine(AnimatePress());
        }
    }

    private IEnumerator AnimatePress()
    {
        isPressing = true;
        Vector3 initial = transform.localPosition;
        transform.localPosition += new Vector3(0, 0, 0.015f);
        yield return new WaitForSeconds(0.12f);
        transform.localPosition = initial;
        isPressing = false;
    }
}

/// <summary>
/// Componente auxiliar adjuntado a cada producto dispensado para asegurar
/// la detección de colisión con el receptor de caída.
/// </summary>
public class VendingProduct : MonoBehaviour
{
    private SerialBridge bridge;
    private int slotNumber;
    private bool detected = false;

    public bool IsProcessed { get; set; } = false;

    public void Setup(SerialBridge ownerBridge, int slot)
    {
        bridge = ownerBridge;
        slotNumber = slot;
    }

    private void OnTriggerEnter(Collider other)
    {
        CheckDrop(other);
    }

    private void OnCollisionEnter(Collision collision)
    {
        CheckDrop(collision.collider);
    }

    private void CheckDrop(Collider col)
    {
        if (detected || bridge == null || IsProcessed) return;

        if (col == bridge.dropReceiverCollider ||
            col.gameObject.name.Contains("DropReceiver") ||
            (col is BoxCollider && col.isTrigger))
        {
            detected = true;
            bridge.OnProductDropped(gameObject);
        }
    }
}
