using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// BuildScene: Generador Procedural del Gemelo Digital GROG (FUNTEC 2026).
/// Construye una escena 3D profesional con TRES MÁQUINAS FÍSICAMENTE INDEPENDIENTES:
/// 1. MÁQUINA 1: Expendedora de Snacks y Sólidos (VENDING-01) en X = -3.8f.
/// 2. MÁQUINA 2: Refrigerador de Bebidas Frías a 4.2 °C (COOLER-01) en X = 0.0f.
/// 3. MÁQUINA 3: Cafetera Automática Especializada a 92 °C (COFFEE-01) en X = +3.8f.
/// 4. GROG Universal Edge Gateway (ESP32) + Universal Machine Adapter en nivel intermedio.
/// 5. Capa Cloud Distribuida con Proof of Service multi-evidencia.
/// 6. GROG Control Center & Digital Twin AI.
/// </summary>
public static class BuildScene
{
    private const string SceneFolder = "Assets/Scenes";
    private const string ScenePath = "Assets/Scenes/VendingScene.unity";
    private const string MaterialsFolder = "Assets/Materials";
    private const string ModelsFolder = "Assets/Models";

    [MenuItem("Tools/Generar Máquina Vending")]
    public static void GenerarMaquina3D()
    {
        Debug.Log("[BuildScene] Iniciando generación de TRES MÁQUINAS INDEPENDIENTES + Gemelo Digital GROG (FUNTEC 2026)...");

        try
        {
            if (EditorApplication.isPlaying)
            {
                Debug.LogWarning("[BuildScene] Por favor sal del modo Play antes de generar la escena.");
                return;
            }

            if (!Directory.Exists(SceneFolder)) Directory.CreateDirectory(SceneFolder);
            if (!Directory.Exists(MaterialsFolder)) Directory.CreateDirectory(MaterialsFolder);
            if (!Directory.Exists(ModelsFolder)) Directory.CreateDirectory(ModelsFolder);

            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            Mesh springMesh = CreateHelicalSpringMesh();
            SaveMeshAsset(springMesh, $"{ModelsFolder}/HelicalSpring.asset");

            // Materiales PBR
            Material matChassisDark = GetOrCreateMaterial("Mat_ChassisTitanium", new Color(0.12f, 0.14f, 0.17f), 0.7f, 0.3f);
            Material matCoolerWhite = GetOrCreateMaterial("Mat_CoolerWhite", new Color(0.92f, 0.94f, 0.96f), 0.85f, 0.2f);
            Material matCoffeeChassis = GetOrCreateMaterial("Mat_CoffeeChassis", new Color(0.08f, 0.08f, 0.10f), 0.85f, 0.5f);
            Material matCoffeeChrome = GetOrCreateMaterial("Mat_CoffeeChrome", new Color(0.92f, 0.93f, 0.95f), 0.95f, 0.95f);
            Material matShelf = GetOrCreateMaterial("Mat_SteelShelf", new Color(0.85f, 0.87f, 0.90f), 0.9f, 0.8f);
            Material matSpring = GetOrCreateMaterial("Mat_HelicalChrome", new Color(0.95f, 0.96f, 0.98f), 0.95f, 0.92f);
            Material matGlass = CreateGlassMaterial("Mat_CutawayGlass", new Color(0.85f, 0.92f, 1.0f, 0.25f));
            Material matCoolerGlass = CreateGlassMaterial("Mat_CoolerGlass", new Color(0.65f, 0.88f, 1.0f, 0.30f));
            Material matAmberGlass = CreateGlassMaterial("Mat_CoffeeAmberGlass", new Color(0.70f, 0.45f, 0.15f, 0.45f));
            Material matPcb = GetOrCreateMaterial("Mat_PcbBoard", new Color(0.05f, 0.35f, 0.15f), 0.5f, 0.2f);
            Material matPcbBlue = GetOrCreateMaterial("Mat_PcbSensorBlue", new Color(0.08f, 0.28f, 0.65f), 0.5f, 0.2f);
            Material matPcbAdapter = GetOrCreateMaterial("Mat_PcbAdapterGold", new Color(0.75f, 0.55f, 0.10f), 0.6f, 0.4f);
            Material matMdbCable = GetOrCreateEmissiveMaterial("Mat_MdbCable", new Color(0.1f, 0.85f, 1.0f), 3.2f);
            Material matEdgeGateway = GetOrCreateMaterial("Mat_EdgeGateway", new Color(0.18f, 0.20f, 0.24f), 0.8f, 0.6f);
            Material matCloudCard = CreateGlassMaterial("Mat_CloudCardHolo", new Color(0.10f, 0.35f, 0.70f, 0.60f));
            Material matProofIdle = GetOrCreateEmissiveMaterial("Mat_ProofIdle", new Color(0.3f, 0.4f, 0.5f), 0.5f);
            Material matProofVerified = GetOrCreateEmissiveMaterial("Mat_ProofVerified", new Color(0.1f, 1.0f, 0.35f), 4.5f);
            Material matProofFailure = GetOrCreateEmissiveMaterial("Mat_ProofFailure", new Color(1.0f, 0.2f, 0.15f), 4.5f);
            Material matTwinHolo = CreateGlassMaterial("Mat_DigitalTwinHolo", new Color(0.15f, 0.75f, 1.0f, 0.35f));
            Material matAiCore = GetOrCreateEmissiveMaterial("Mat_AiCore", new Color(0.85f, 0.25f, 1.0f), 3.8f);
            Material matDisplayBezel = GetOrCreateMaterial("Mat_DisplayBezel", new Color(0.04f, 0.04f, 0.04f), 0.8f, 0.2f);
            Material matDisplayScreen = GetOrCreateMaterial("Mat_DisplayScreen", new Color(0.02f, 0.14f, 0.06f), 0.9f, 0.1f);
            Material matQR = GetOrCreateMaterial("Mat_VendingQR", Color.white, 0.1f, 0.0f, "Unlit/Texture");
            Material matCanCola = GetOrCreateMaterial("Mat_CanCola", new Color(0.88f, 0.12f, 0.12f), 0.9f, 0.6f);
            Material matCanLemon = GetOrCreateMaterial("Mat_CanLemon", new Color(0.18f, 0.82f, 0.22f), 0.9f, 0.6f);
            Material matCanOrange = GetOrCreateMaterial("Mat_CanOrange", new Color(1.0f, 0.55f, 0.08f), 0.9f, 0.6f);
            Material matCanWater = GetOrCreateMaterial("Mat_CanWater", new Color(0.2f, 0.75f, 0.95f), 0.9f, 0.6f);
            Material matCoffeeLiquid = GetOrCreateMaterial("Mat_CoffeeLiquid", new Color(0.22f, 0.11f, 0.05f), 0.9f, 0.1f);
            Material matCupPaper = GetOrCreateMaterial("Mat_CupPaper", new Color(0.96f, 0.94f, 0.90f), 0.3f, 0.0f);

            SetupEnvironment();

            // Raíz de la Arquitectura
            GameObject managerRoot = new GameObject("GROG_MDB_DigitalTwin_Architecture");
            managerRoot.transform.position = Vector3.zero;

            MDBArchitectureManager archMgr = managerRoot.AddComponent<MDBArchitectureManager>();
            SerialBridge bridge = managerRoot.AddComponent<SerialBridge>();
            archMgr.mainCamera = Camera.main;
            archMgr.springMesh = springMesh;
            archMgr.matSpring = matSpring;
            archMgr.matProofIdle = matProofIdle;
            archMgr.matProofVerified = matProofVerified;
            archMgr.matProofFailure = matProofFailure;

            bridge.orchestratorUrl = "http://127.0.0.1:8010";
            bridge.cloudflareGatewayUrl = "https://passivism-sighing-condense.ngrok-free.dev";
            archMgr.orchestratorUrl = bridge.orchestratorUrl;
            archMgr.cloudflareGatewayUrl = bridge.cloudflareGatewayUrl;
            archMgr.serialBridge = bridge;

            CreateAcademicBanner(managerRoot.transform);

            // ═════════════════════════════════════════════════════════════════════════════
            // 1. MÁQUINA 1: EXPENDEDORA DE SNACKS Y SÓLIDOS (VENDING-01) - IZQUIERDA (X = -3.8f)
            // ═════════════════════════════════════════════════════════════════════════════
            GameObject vendingRoot = new GameObject("Machine1_VENDING-01_Snacks");
            vendingRoot.transform.SetParent(managerRoot.transform, false);
            vendingRoot.transform.position = new Vector3(-3.8f, 0f, 0f);

            BuildSnackVendingMachine(vendingRoot.transform, archMgr, bridge,
                matChassisDark, matShelf, matGlass, matDisplayBezel, matDisplayScreen, matQR, matPcbBlue);

            // ═════════════════════════════════════════════════════════════════════════════
            // 2. MÁQUINA 2: REFRIGERADOR DE BEBIDAS A 4.2 °C (COOLER-01) - CENTRO (X = 0.0f)
            // ═════════════════════════════════════════════════════════════════════════════
            GameObject coolerRoot = new GameObject("Machine2_COOLER-01_RefrigeratedDrinks");
            coolerRoot.transform.SetParent(managerRoot.transform, false);
            coolerRoot.transform.position = new Vector3(0f, 0f, 0f);

            BuildCoolerDrinkMachine(coolerRoot.transform, archMgr,
                matCoolerWhite, matShelf, matCoolerGlass, matDisplayBezel, matDisplayScreen,
                matCanCola, matCanLemon, matCanOrange, matCanWater);

            // ═════════════════════════════════════════════════════════════════════════════
            // 3. MÁQUINA 3: CAFETERA ESPECIALIZADA (COFFEE-01) - DERECHA (X = +3.8f)
            // ═════════════════════════════════════════════════════════════════════════════
            GameObject coffeeRoot = new GameObject("Machine3_COFFEE-01_SpecialtyBarista");
            coffeeRoot.transform.SetParent(managerRoot.transform, false);
            coffeeRoot.transform.position = new Vector3(3.8f, 0f, 0f);

            BuildSpecialtyCoffeeMachine(coffeeRoot.transform, archMgr,
                matCoffeeChassis, matCoffeeChrome, matAmberGlass, matCoffeeLiquid, matCupPaper, matDisplayBezel, matDisplayScreen);

            // ═════════════════════════════════════════════════════════════════════════════
            // 4. GROG UNIVERSAL EDGE & ADAPTADOR MODULAR (NIVEL ELEVADO POSTERIOR)
            // ═════════════════════════════════════════════════════════════════════════════
            GameObject edgeRoot = new GameObject("Layer_UniversalEdge_And_Adapters");
            edgeRoot.transform.SetParent(managerRoot.transform, false);
            edgeRoot.transform.position = new Vector3(-1.8f, 3.2f, 0.4f);

            BuildUniversalEdgeAndAdapters(edgeRoot.transform, archMgr, matEdgeGateway, matPcbAdapter, matMdbCable);

            // ═════════════════════════════════════════════════════════════════════════════
            // 5. CAPA INDUSTRIAL MDB (VMC & PERIFÉRICOS)
            // ═════════════════════════════════════════════════════════════════════════════
            GameObject mdbRoot = new GameObject("Layer_MDB_IndustrialArchitecture");
            mdbRoot.transform.SetParent(managerRoot.transform, false);
            mdbRoot.transform.position = new Vector3(-3.8f, 0f, 0f);

            BuildMDBSubsystem(mdbRoot.transform, archMgr, matPcb, matMdbCable);

            // ═════════════════════════════════════════════════════════════════════════════
            // 6. GROG CLOUD PLATFORM & PROOF OF SERVICE
            // ═════════════════════════════════════════════════════════════════════════════
            GameObject cloudRoot = new GameObject("Layer_GROG_CloudPlatform");
            cloudRoot.transform.SetParent(managerRoot.transform, false);
            cloudRoot.transform.position = new Vector3(0f, 5.2f, 0.2f);

            BuildCloudPlatform(cloudRoot.transform, archMgr, matCloudCard, matProofIdle);

            // ═════════════════════════════════════════════════════════════════════════════
            // 7. GROG CONTROL CENTER & DIGITAL TWIN AI
            // ═════════════════════════════════════════════════════════════════════════════
            GameObject twinRoot = new GameObject("Layer_GROG_ControlCenter_DigitalTwin");
            twinRoot.transform.SetParent(managerRoot.transform, false);
            twinRoot.transform.position = new Vector3(1.8f, 3.2f, 0.4f);

            BuildDigitalTwinAndAI(twinRoot.transform, archMgr, matTwinHolo, matAiCore);

            // Conexiones visuales de buses de datos
            SetupDataBusCables(managerRoot.transform, archMgr, matMdbCable);

            EditorSceneManager.MarkSceneDirty(scene);
            bool saved = EditorSceneManager.SaveScene(scene, ScenePath);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log($"[BuildScene] ¡Escena con 3 MÁQUINAS INDEPENDIENTES generada en {ScenePath}! (Éxito: {saved})");
        }
        catch (Exception ex)
        {
            Debug.LogError($"[BuildScene] Error generando la escena: {ex.Message}\n{ex.StackTrace}");
        }
    }

    #region 1. Máquina Expendedora de Snacks (VENDING-01)
    private static void BuildSnackVendingMachine(
        Transform parent, MDBArchitectureManager archMgr, SerialBridge bridge,
        Material matChassis, Material matShelf, Material matGlass,
        Material matDisplayBezel, Material matDisplayScreen, Material matQR, Material matSensorBlue)
    {
        CreateBox("Vending_Back", parent, new Vector3(0f, 1.55f, 0.45f), new Vector3(1.85f, 3.1f, 0.08f), matChassis);
        CreateBox("Vending_Left", parent, new Vector3(-0.90f, 1.55f, 0f), new Vector3(0.08f, 3.1f, 0.98f), matChassis);
        CreateBox("Vending_Right", parent, new Vector3(0.90f, 1.55f, 0f), new Vector3(0.08f, 3.1f, 0.98f), matChassis);
        CreateBox("Vending_Top", parent, new Vector3(0f, 3.06f, 0f), new Vector3(1.85f, 0.08f, 0.98f), matChassis);
        CreateBox("Vending_Bottom", parent, new Vector3(0f, 0.08f, 0f), new Vector3(1.85f, 0.16f, 0.98f), matChassis);

        CreateBox("Marquee_Box", parent, new Vector3(0f, 2.90f, -0.45f), new Vector3(1.80f, 0.28f, 0.08f), matChassis);
        Create3DText("Marquee_Text", parent, new Vector3(0f, 2.90f, -0.50f), "VENDING-01 • SNACKS & SÓLIDOS (MDB L3)", 0.020f, Color.cyan, TextAlignment.Center);

        CreateBox("Front_Glass", parent, new Vector3(-0.25f, 1.75f, -0.45f), new Vector3(1.20f, 1.95f, 0.02f), matGlass);

        GameObject controlCol = new GameObject("Vending_Control_Column");
        controlCol.transform.SetParent(parent, false);
        controlCol.transform.localPosition = new Vector3(0.60f, 1.60f, -0.45f);

        CreateBox("Panel_Face", controlCol.transform, Vector3.zero, new Vector3(0.48f, 2.25f, 0.06f), matChassis);

        // Display LCD
        CreateBox("Display_Bezel", controlCol.transform, new Vector3(0f, 0.88f, -0.04f), new Vector3(0.42f, 0.16f, 0.025f), matDisplayBezel);
        CreateBox("Display_Screen", controlCol.transform, new Vector3(0f, 0.88f, -0.055f), new Vector3(0.38f, 0.12f, 0.015f), matDisplayScreen);
        bridge.displayScreen = Create3DText("Display_Text", controlCol.transform, new Vector3(0f, 0.88f, -0.07f), "SELECCIONE: 1-9", 0.018f, new Color(0.2f, 1.0f, 0.4f), TextAlignment.Center);

        // Teclado 3x3 interactivo
        float[] btnX = new float[] { -0.11f, 0.0f, 0.11f };
        float[] btnY = new float[] { 0.65f, 0.52f, 0.39f };
        int bNum = 1;
        for (int r = 0; r < 3; r++)
        {
            for (int c = 0; c < 3; c++)
            {
                Vector3 bPos = new Vector3(btnX[c], btnY[r], -0.045f);
                GameObject bObj = CreateBox($"KeyBtn_{bNum}", controlCol.transform, bPos, new Vector3(0.09f, 0.09f, 0.03f), matDisplayBezel);
                Create3DText($"KeyLbl_{bNum}", controlCol.transform, bPos + new Vector3(0f, 0f, -0.02f), bNum.ToString(), 0.032f, Color.white, TextAlignment.Center);
                VendingButton btnComp = bObj.AddComponent<VendingButton>();
                btnComp.targetMachineId = "VENDING-01";
                btnComp.slotNumber = bNum;
                bNum++;
            }
        }

        // PANTALLA FÍSICA 3D DE QR ACOPLADA A VENDING-01
        Create3DText("QR_Header", controlCol.transform, new Vector3(0f, 0.22f, -0.05f), "PAGO CON QR DINÁMICO", 0.013f, Color.white, TextAlignment.Center);
        CreateBox("Display_QR_Bezel", controlCol.transform, new Vector3(0f, 0.06f, -0.04f), new Vector3(0.34f, 0.28f, 0.025f), matDisplayBezel);
        GameObject qrObj = CreateBox("Vending_Display_QR", controlCol.transform, new Vector3(0f, 0.06f, -0.055f), new Vector3(0.28f, 0.24f, 0.01f), matQR);
        Renderer qrRend = qrObj.GetComponent<Renderer>();
        bridge.qrDisplayRenderer = qrRend;
        archMgr.vendingQrRenderer = qrRend;

        CreateBox("Front_Bill_Mouth", controlCol.transform, new Vector3(0f, -0.20f, -0.04f), new Vector3(0.30f, 0.07f, 0.03f), matDisplayBezel);
        Create3DText("Front_Bill_Lbl", controlCol.transform, new Vector3(0f, -0.15f, -0.06f), "BILLETES (MDB)", 0.012f, Color.yellow, TextAlignment.Center);

        CreateBox("Front_Coin_Slot", controlCol.transform, new Vector3(0f, -0.34f, -0.04f), new Vector3(0.18f, 0.04f, 0.03f), matDisplayBezel);
        Create3DText("Front_Coin_Lbl", controlCol.transform, new Vector3(0f, -0.30f, -0.06f), "MONEDAS (MDB)", 0.012f, Color.yellow, TextAlignment.Center);

        CreateBox("Front_Coin_Return", controlCol.transform, new Vector3(0f, -0.58f, -0.04f), new Vector3(0.24f, 0.16f, 0.05f), matChassis);
        Create3DText("Front_Return_Lbl", controlCol.transform, new Vector3(0f, -0.48f, -0.06f), "CAMBIO", 0.013f, Color.white, TextAlignment.Center);

        // Estantes Paramétricos de Snacks
        GameObject snacksParent = new GameObject("Snack_Shelves_Parametric");
        snacksParent.transform.SetParent(parent, false);
        snacksParent.transform.localPosition = new Vector3(-0.25f, 0f, 0f);
        archMgr.snackShelvesParent = snacksParent.transform;

        CreateBox("Shelf_1", snacksParent.transform, new Vector3(0f, 2.48f, 0.12f), new Vector3(1.18f, 0.035f, 0.65f), matShelf);
        CreateBox("Shelf_2", snacksParent.transform, new Vector3(0f, 1.98f, 0.12f), new Vector3(1.18f, 0.035f, 0.65f), matShelf);
        CreateBox("Shelf_3", snacksParent.transform, new Vector3(0f, 1.48f, 0.12f), new Vector3(1.18f, 0.035f, 0.65f), matShelf);

        // Tolva receptora y sensor HC-SR04
        GameObject dropTray = new GameObject("Drop_Receiver_Tray");
        dropTray.transform.SetParent(parent, false);
        dropTray.transform.localPosition = new Vector3(-0.25f, 0.42f, -0.15f);

        CreateBox("Tray_Bottom", dropTray.transform, Vector3.zero, new Vector3(1.20f, 0.08f, 0.65f), matChassis);
        CreateBox("Tray_Ramp", dropTray.transform, new Vector3(0f, 0.18f, 0.10f), new Vector3(1.16f, 0.04f, 0.45f), matShelf)
            .transform.localRotation = Quaternion.Euler(18f, 0f, 0f);

        GameObject triggerObj = new GameObject("Drop_Trigger_Zone");
        triggerObj.transform.SetParent(dropTray.transform, false);
        triggerObj.transform.localPosition = new Vector3(0f, 0.32f, 0f);
        BoxCollider bc = triggerObj.AddComponent<BoxCollider>();
        bc.isTrigger = true;
        bc.size = new Vector3(1.20f, 0.65f, 0.65f);
        bridge.dropReceiverCollider = bc;
        archMgr.dropTriggerCollider = bc;

        GameObject hcSr04 = new GameObject("Sensor_HC-SR04");
        hcSr04.transform.SetParent(dropTray.transform, false);
        hcSr04.transform.localPosition = new Vector3(0f, 0.52f, 0.22f);
        archMgr.hcSr04SensorTransform = hcSr04.transform;

        CreateBox("HCSR04_Pcb", hcSr04.transform, Vector3.zero, new Vector3(0.24f, 0.11f, 0.015f), matSensorBlue);

        GameObject trigCyl = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        trigCyl.name = "Transducer_Trigger";
        trigCyl.transform.SetParent(hcSr04.transform, false);
        trigCyl.transform.localPosition = new Vector3(-0.065f, 0f, -0.035f);
        trigCyl.transform.localScale = new Vector3(0.068f, 0.035f, 0.068f);
        trigCyl.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
        AssignMaterial(trigCyl, matShelf);

        GameObject echoCyl = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        echoCyl.name = "Transducer_Echo";
        echoCyl.transform.SetParent(hcSr04.transform, false);
        echoCyl.transform.localPosition = new Vector3(0.065f, 0f, -0.035f);
        echoCyl.transform.localScale = new Vector3(0.068f, 0.035f, 0.068f);
        echoCyl.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
        AssignMaterial(echoCyl, matShelf);

        archMgr.distanceGaugeText = Create3DText("HCSR04_Label", hcSr04.transform, new Vector3(0f, 0.11f, -0.03f), "32.5 cm\n[HC-SR04]", 0.014f, Color.green, TextAlignment.Center);
    }
    #endregion

    #region 2. Máquina de Bebidas Refrigeradas (COOLER-01 - Botellero Powerade, Foto 5)
    private static void BuildCoolerDrinkMachine(
        Transform parent, MDBArchitectureManager archMgr,
        Material matCoolerWhite, Material matShelf, Material matCoolerGlass,
        Material matDisplayBezel, Material matDisplayScreen,
        Material matCanCola, Material matCanLemon, Material matCanOrange, Material matCanWater)
    {
        Material matPoweradeBlue = GetOrCreateMaterial("Mat_PoweradeBlue", new Color(0.08f, 0.38f, 0.85f), 0.85f, 0.3f);
        Material matPoweradeBlack = GetOrCreateMaterial("Mat_PoweradeBlack", new Color(0.06f, 0.07f, 0.09f), 0.8f, 0.4f);
        Material matSilverTrim = GetOrCreateMaterial("Mat_PoweradeSilver", new Color(0.80f, 0.84f, 0.90f), 0.9f, 0.8f);
        Material matQR = GetOrCreateMaterial("Mat_VendingQR", Color.white, 0.1f, 0.0f, "Unlit/Texture");

        // Chasis del botellero Powerade
        CreateBox("Powerade_Back", parent, new Vector3(0f, 1.55f, 0.45f), new Vector3(1.75f, 3.1f, 0.08f), matPoweradeBlack);
        CreateBox("Powerade_Left", parent, new Vector3(-0.85f, 1.55f, 0f), new Vector3(0.08f, 3.1f, 0.98f), matPoweradeBlack);
        CreateBox("Powerade_Right", parent, new Vector3(0.85f, 1.55f, 0f), new Vector3(0.08f, 3.1f, 0.98f), matPoweradeBlack);
        CreateBox("Powerade_Top", parent, new Vector3(0f, 3.06f, 0f), new Vector3(1.75f, 0.08f, 0.98f), matPoweradeBlack);
        CreateBox("Powerade_Bottom", parent, new Vector3(0f, 0.08f, 0f), new Vector3(1.75f, 0.16f, 0.98f), matPoweradeBlack);

        // Panel curvo frontal superior negro con gran logo POWERADE
        CreateBox("Powerade_Header_Plate", parent, new Vector3(-0.20f, 2.70f, -0.45f), new Vector3(1.25f, 0.65f, 0.06f), matPoweradeBlack);
        Create3DText("Powerade_Logo", parent, new Vector3(-0.20f, 2.75f, -0.49f), "POWER\nADE", 0.044f, Color.white, TextAlignment.Center);

        // Curvatura aerodinámica lateral plateada/azul (según foto 5)
        CreateBox("Powerade_Silver_Wave", parent, new Vector3(0.40f, 1.65f, -0.44f), new Vector3(0.12f, 2.75f, 0.04f), matSilverTrim);

        // Panel frontal inferior azul con eslogan
        CreateBox("Powerade_Lower_Blue", parent, new Vector3(-0.20f, 0.85f, -0.45f), new Vector3(1.25f, 1.35f, 0.06f), matPoweradeBlue);
        Create3DText("Powerade_Slogan_1", parent, new Vector3(-0.35f, 1.15f, -0.49f), "El agua no basta\npara tener Power.", 0.016f, Color.white, TextAlignment.Left);
        Create3DText("Powerade_Slogan_2", parent, new Vector3(-0.35f, 0.35f, -0.49f), "PAUSA ES POWER", 0.014f, new Color(0.85f, 0.92f, 1.0f), TextAlignment.Left);

        // 3 Ventanas Verticales de muestra de producto (según foto 5)
        float[] winX = new float[] { -0.58f, -0.22f, 0.14f };
        string[] winNames = new string[] { "Powerade\n8.00 BS.", "Powerade Azul\n8.00 BS.", "Coca-Cola\n8.00 BS." };
        Material[] winMats = new Material[] { matCanLemon, matCanWater, matCanCola };

        for (int w = 0; w < 3; w++)
        {
            // Marco de ventana
            CreateBox($"Window_Frame_{w + 1}", parent, new Vector3(winX[w], 1.85f, -0.46f), new Vector3(0.26f, 0.68f, 0.03f), matCoolerWhite);
            CreateBox($"Window_Glass_{w + 1}", parent, new Vector3(winX[w], 1.85f, -0.47f), new Vector3(0.22f, 0.62f, 0.01f), matCoolerGlass);

            // Botella en exhibición
            GameObject bottle = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            bottle.name = $"Sample_Bottle_{w + 1}";
            bottle.transform.SetParent(parent, false);
            bottle.transform.localPosition = new Vector3(winX[w], 1.78f, -0.44f);
            bottle.transform.localScale = new Vector3(0.11f, 0.16f, 0.11f);
            AssignMaterial(bottle, winMats[w]);

            // Etiqueta de precio
            Create3DText($"Win_Price_{w + 1}", parent, new Vector3(winX[w], 2.10f, -0.48f), winNames[w], 0.011f, Color.black, TextAlignment.Center);

            // Botón redondo frontal debajo de cada ventana (con VendingButton para compra directa)
            GameObject selBtn = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            selBtn.name = $"Btn_Powerade_Select_{w + 1}";
            selBtn.transform.SetParent(parent, false);
            selBtn.transform.localPosition = new Vector3(winX[w], 1.45f, -0.46f);
            selBtn.transform.localScale = new Vector3(0.09f, 0.02f, 0.09f);
            selBtn.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
            AssignMaterial(selBtn, matSilverTrim);

            VendingButton btnComp = selBtn.AddComponent<VendingButton>();
            btnComp.targetMachineId = "COOLER-01";
            btnComp.slotNumber = w + 1;

            Create3DText($"Btn_Txt_{w + 1}", parent, new Vector3(winX[w], 1.35f, -0.48f), "[COMPRAR]", 0.010f, Color.white, TextAlignment.Center);
        }

        // COLUMNA TÉCNICA LATERAL DERECHA (Billetero, Pantalla QR 3D, LCD)
        GameObject sideColumn = new GameObject("Cooler_Control_Column");
        sideColumn.transform.SetParent(parent, false);
        sideColumn.transform.localPosition = new Vector3(0.60f, 1.65f, -0.45f);

        CreateBox("Side_Panel_Face", sideColumn.transform, Vector3.zero, new Vector3(0.40f, 2.20f, 0.05f), matPoweradeBlack);

        // Display LCD de Temperatura y Estado
        CreateBox("Cooler_LCD_Bezel", sideColumn.transform, new Vector3(0f, 0.88f, -0.035f), new Vector3(0.36f, 0.14f, 0.02f), matDisplayBezel);
        CreateBox("Cooler_LCD_Screen", sideColumn.transform, new Vector3(0f, 0.88f, -0.050f), new Vector3(0.32f, 0.10f, 0.015f), matDisplayScreen);
        archMgr.coolerTempText = Create3DText("Cooler_Temp_Text", sideColumn.transform, new Vector3(0f, 0.88f, -0.065f), "4.2 °C\n[REFRIGERADO]", 0.014f, Color.cyan, TextAlignment.Center);

        // PANTALLA FÍSICA 3D DE QR ACOPLADA A COOLER-01
        Create3DText("Cooler_QR_Title", sideColumn.transform, new Vector3(0f, 0.58f, -0.045f), "GROG QR PAY", 0.014f, Color.cyan, TextAlignment.Center);
        CreateBox("Cooler_QR_Bezel", sideColumn.transform, new Vector3(0f, 0.38f, -0.035f), new Vector3(0.34f, 0.30f, 0.02f), matDisplayBezel);
        GameObject coolerQrObj = CreateBox("Cooler_Display_QR", sideColumn.transform, new Vector3(0f, 0.38f, -0.050f), new Vector3(0.28f, 0.25f, 0.01f), matQR);
        archMgr.coolerQrRenderer = coolerQrObj.GetComponent<Renderer>();

        // Billetero y Monedero con sticker de instrucciones
        CreateBox("Cooler_Bill_Acceptor", sideColumn.transform, new Vector3(0f, 0.06f, -0.035f), new Vector3(0.28f, 0.22f, 0.03f), matDisplayBezel);
        CreateBox("Cooler_Bill_Slot", sideColumn.transform, new Vector3(0f, 0.06f, -0.055f), new Vector3(0.20f, 0.04f, 0.02f), matPoweradeBlack);
        Create3DText("Cooler_Bill_Text", sideColumn.transform, new Vector3(0f, 0.12f, -0.065f), "BILLETES", 0.011f, Color.yellow, TextAlignment.Center);

        CreateBox("Cooler_Coin_Slot", sideColumn.transform, new Vector3(0f, -0.16f, -0.035f), new Vector3(0.16f, 0.04f, 0.02f), matDisplayBezel);
        Create3DText("Cooler_Coin_Text", sideColumn.transform, new Vector3(0f, -0.12f, -0.055f), "MONEDAS", 0.010f, Color.yellow, TextAlignment.Center);

        CreateBox("Cooler_Coin_Return", sideColumn.transform, new Vector3(0f, -0.65f, -0.035f), new Vector3(0.22f, 0.18f, 0.04f), matPoweradeBlack);
        Create3DText("Cooler_Return_Text", sideColumn.transform, new Vector3(0f, -0.52f, -0.055f), "CAMBIO Y\nDEVOLUCIÓN", 0.010f, Color.white, TextAlignment.Center);

        // Bandeja inferior de salida de producto (azul con cartel "RETIRE SU PRODUCTO")
        CreateBox("Cooler_Exit_Cavity", parent, new Vector3(-0.20f, 0.52f, -0.44f), new Vector3(0.65f, 0.24f, 0.12f), matPoweradeBlack);
        CreateBox("Cooler_Exit_Door", parent, new Vector3(-0.20f, 0.52f, -0.47f), new Vector3(0.60f, 0.20f, 0.03f), matPoweradeBlue);
        Create3DText("Cooler_Exit_Text", parent, new Vector3(-0.20f, 0.52f, -0.50f), "RETIRE SU PRODUCTO", 0.013f, Color.white, TextAlignment.Center);
    }
    #endregion

    #region 3. Máquina de Café Especializada (COFFEE-01 - HotBox Café / Necta Concerto, Fotos 1-4)
    private static void BuildSpecialtyCoffeeMachine(
        Transform parent, MDBArchitectureManager archMgr,
        Material matCoffeeChassis, Material matCoffeeChrome, Material matAmberGlass,
        Material matLiquid, Material matCup, Material matBezel, Material matScreen)
    {
        archMgr.coffeeMachineRoot = parent;
        Material matHotBoxMagenta = GetOrCreateEmissiveMaterial("Mat_HotBoxMagenta", new Color(0.75f, 0.10f, 0.85f), 2.2f);
        Material matMarqueeCream = GetOrCreateMaterial("Mat_MarqueeCream", new Color(0.96f, 0.94f, 0.85f), 0.8f, 0.1f);
        Material matNectaSilver = GetOrCreateMaterial("Mat_NectaSilver", new Color(0.82f, 0.84f, 0.88f), 0.9f, 0.8f);
        Material matLedBlue = GetOrCreateEmissiveMaterial("Mat_LedBlue", new Color(0.15f, 0.70f, 1.0f), 3.5f);
        Material matQR = GetOrCreateMaterial("Mat_VendingQR", Color.white, 0.1f, 0.0f, "Unlit/Texture");

        // Chasis principal negro satinado
        CreateBox("HotBox_Chassis", parent, new Vector3(0f, 1.45f, 0f), new Vector3(1.35f, 2.90f, 0.85f), matCoffeeChassis);

        // 1. MARQUESINA SUPERIOR ILUMINADA ("Pruebe nuestras nuevas variedades" con tazas)
        CreateBox("Marquee_Frame", parent, new Vector3(-0.15f, 2.45f, -0.44f), new Vector3(0.88f, 0.65f, 0.05f), matMarqueeCream);
        Create3DText("Marquee_Header_1", parent, new Vector3(-0.15f, 2.65f, -0.48f), "Pruebe nuestras\nnuevas variedades", 0.016f, new Color(0.75f, 0.55f, 0.10f), TextAlignment.Center);
        Create3DText("Marquee_Items", parent, new Vector3(-0.15f, 2.32f, -0.48f), "☕ CAFÉ AVELLANAS    ☕ CAPPUCCINO\n        ☕ CHOCOLATE", 0.012f, new Color(0.40f, 0.25f, 0.10f), TextAlignment.Center);

        // 2. PANEL DE SELECCIÓN CENTRAL CON AROS LED AZULES Y BOTONES
        GameObject selectionPanel = new GameObject("HotBox_Selection_Panel");
        selectionPanel.transform.SetParent(parent, false);
        selectionPanel.transform.localPosition = new Vector3(-0.15f, 1.55f, -0.44f);

        CreateBox("Sel_Panel_Back", selectionPanel.transform, Vector3.zero, new Vector3(0.78f, 0.85f, 0.04f), matBezel);
        Create3DText("Sugar_Minus", selectionPanel.transform, new Vector3(-0.24f, 0.36f, -0.035f), "AZÚCAR -", 0.011f, Color.white, TextAlignment.Center);
        Create3DText("Sugar_Plus", selectionPanel.transform, new Vector3(0.24f, 0.36f, -0.035f), "AZÚCAR +", 0.011f, Color.white, TextAlignment.Center);

        string[] hotboxDrinks = new string[]
        {
            "Café Avellanas  6.00 Bs", "Cappuccino Av.  6.00 Bs",
            "Chocolate      6.00 Bs", "Espresso        5.00 Bs",
            "Americano      5.00 Bs", "Café c/ Leche   6.00 Bs",
            "Mocaccino      6.00 Bs", "Vainilla Franc. 6.00 Bs"
        };

        float[] rowY = new float[] { 0.26f, 0.13f, 0.0f, -0.13f };
        int dIdx = 0;
        for (int r = 0; r < 4; r++)
        {
            // Columna Izquierda
            Create3DText($"Hot_Txt_L_{r}", selectionPanel.transform, new Vector3(-0.16f, rowY[r], -0.035f), hotboxDrinks[dIdx], 0.009f, Color.white, TextAlignment.Center);
            GameObject btnL = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            btnL.name = $"Btn_Hot_{dIdx + 1}";
            btnL.transform.SetParent(selectionPanel.transform, false);
            btnL.transform.localPosition = new Vector3(-0.02f, rowY[r], -0.03f);
            btnL.transform.localScale = new Vector3(0.035f, 0.015f, 0.035f);
            btnL.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
            AssignMaterial(btnL, matLedBlue);

            VendingButton vbtnL = btnL.AddComponent<VendingButton>();
            vbtnL.targetMachineId = "COFFEE-01";
            vbtnL.slotNumber = dIdx + 1;
            dIdx++;

            // Columna Derecha
            Create3DText($"Hot_Txt_R_{r}", selectionPanel.transform, new Vector3(0.24f, rowY[r], -0.035f), hotboxDrinks[dIdx], 0.009f, Color.white, TextAlignment.Center);
            GameObject btnR = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            btnR.name = $"Btn_Hot_{dIdx + 1}";
            btnR.transform.SetParent(selectionPanel.transform, false);
            btnR.transform.localPosition = new Vector3(0.06f, rowY[r], -0.03f);
            btnR.transform.localScale = new Vector3(0.035f, 0.015f, 0.035f);
            btnR.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
            AssignMaterial(btnR, matLedBlue);

            VendingButton vbtnR = btnR.AddComponent<VendingButton>();
            vbtnR.targetMachineId = "COFFEE-01";
            vbtnR.slotNumber = dIdx + 1;
            dIdx++;
        }

        // 3. ALCOBA PROFUNDA DE EROGACIÓN ("LEVANTE Y RECOJA SU VASO")
        CreateBox("Dispense_Alcove_Cavity", parent, new Vector3(-0.15f, 0.85f, -0.25f), new Vector3(0.70f, 0.55f, 0.40f), matCoffeeChassis);
        CreateBox("Drip_Grill", parent, new Vector3(-0.15f, 0.60f, -0.25f), new Vector3(0.65f, 0.04f, 0.35f), matCoffeeChrome);

        GameObject nozzleL = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        nozzleL.name = "Nozzle_L";
        nozzleL.transform.SetParent(parent, false);
        nozzleL.transform.localPosition = new Vector3(-0.19f, 1.05f, -0.25f);
        nozzleL.transform.localScale = new Vector3(0.025f, 0.06f, 0.025f);
        AssignMaterial(nozzleL, matCoffeeChrome);

        GameObject nozzleR = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        nozzleR.name = "Nozzle_R";
        nozzleR.transform.SetParent(parent, false);
        nozzleR.transform.localPosition = new Vector3(-0.11f, 1.05f, -0.25f);
        nozzleR.transform.localScale = new Vector3(0.025f, 0.06f, 0.025f);
        AssignMaterial(nozzleR, matCoffeeChrome);

        GameObject stream = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        stream.name = "Coffee_Liquid_Stream";
        stream.transform.SetParent(parent, false);
        stream.transform.localPosition = new Vector3(-0.15f, 0.85f, -0.25f);
        stream.transform.localScale = new Vector3(0.030f, 0.24f, 0.030f);
        AssignMaterial(stream, matLiquid);
        stream.SetActive(false);
        archMgr.coffeeLiquidStream = stream.transform;

        GameObject cup = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        cup.name = "Coffee_Cup";
        cup.transform.SetParent(parent, false);
        cup.transform.localPosition = new Vector3(-0.15f, 0.68f, -0.25f);
        cup.transform.localScale = new Vector3(0.12f, 0.11f, 0.12f);
        AssignMaterial(cup, matCup);
        archMgr.coffeeCupTransform = cup.transform;

        // Tapa abatible con rótulo
        CreateBox("Cup_Trapdoor", parent, new Vector3(-0.15f, 0.58f, -0.45f), new Vector3(0.55f, 0.08f, 0.02f), matCoffeeChassis);
        Create3DText("Cup_Pickup_Text", parent, new Vector3(-0.15f, 0.58f, -0.47f), "LEVANTE Y\nRECOJA SU VASO", 0.011f, Color.white, TextAlignment.Center);

        // 4. GRAN PANEL INFERIOR PÚRPURA/MAGENTA RETROILUMINADO [HotBox Café]
        CreateBox("HotBox_Neon_Panel", parent, new Vector3(-0.15f, 0.28f, -0.44f), new Vector3(0.85f, 0.48f, 0.04f), matHotBoxMagenta);
        Create3DText("HotBox_Logo_Text", parent, new Vector3(-0.15f, 0.28f, -0.48f), "[HotBox Café]", 0.032f, Color.yellow, TextAlignment.Center);

        // 5. COLUMNA TÉCNICA LATERAL DERECHA (NECTA CONCERTO + BILLETERO + PANTALLA QR 3D)
        GameObject nectaCol = new GameObject("HotBox_Necta_Column");
        nectaCol.transform.SetParent(parent, false);
        nectaCol.transform.localPosition = new Vector3(0.48f, 1.45f, -0.44f);

        CreateBox("Necta_Col_Plate", nectaCol.transform, Vector3.zero, new Vector3(0.38f, 2.75f, 0.05f), matNectaSilver);

        // Placa superior "Concerto NECTA" + WhatsApp
        CreateBox("Necta_Logo_Plate", nectaCol.transform, new Vector3(0f, 1.15f, -0.03f), new Vector3(0.32f, 0.18f, 0.02f), matBezel);
        Create3DText("Necta_Brand_Txt", nectaCol.transform, new Vector3(0f, 1.15f, -0.05f), "Concerto\nNECTA", 0.013f, Color.white, TextAlignment.Center);
        Create3DText("Necta_WhatsApp", nectaCol.transform, new Vector3(0f, 1.28f, -0.035f), "✆ WhatsApp: 624-52480", 0.009f, Color.black, TextAlignment.Center);

        // Billetero con LEDs azules y rojos
        CreateBox("Necta_Bill_Acceptor", nectaCol.transform, new Vector3(0f, 0.85f, -0.035f), new Vector3(0.30f, 0.26f, 0.03f), matCoffeeChassis);
        CreateBox("Necta_Bill_Slot", nectaCol.transform, new Vector3(0f, 0.85f, -0.055f), new Vector3(0.20f, 0.05f, 0.02f), matBezel);
        CreateSphere("Led_Bill_L", nectaCol.transform, new Vector3(-0.08f, 0.85f, -0.06f), new Vector3(0.02f, 0.02f, 0.02f), matLedBlue);
        CreateSphere("Led_Bill_R", nectaCol.transform, new Vector3(0.08f, 0.85f, -0.06f), new Vector3(0.02f, 0.02f, 0.02f), matLedBlue);
        Create3DText("Necta_Bill_Txt", nectaCol.transform, new Vector3(0f, 0.94f, -0.06f), "INSERTE SU BILLETE", 0.009f, Color.yellow, TextAlignment.Center);

        // Display LCD azul
        CreateBox("Necta_LCD_Bezel", nectaCol.transform, new Vector3(0f, 0.62f, -0.035f), new Vector3(0.28f, 0.12f, 0.02f), matBezel);
        CreateBox("Necta_LCD_Screen", nectaCol.transform, new Vector3(0f, 0.62f, -0.050f), new Vector3(0.24f, 0.08f, 0.015f), matLedBlue);
        archMgr.coffeeStatusText = Create3DText("Necta_LCD_Text", nectaCol.transform, new Vector3(0f, 0.62f, -0.065f), "SELECCIONE BEBIDA", 0.011f, Color.white, TextAlignment.Center);

        // PANTALLA FÍSICA 3D DE QR ACOPLADA A COFFEE-01 (Modernización GROG)
        Create3DText("Coffee_QR_Header", nectaCol.transform, new Vector3(0f, 0.45f, -0.035f), "GROG QR PAY", 0.013f, Color.cyan, TextAlignment.Center);
        CreateBox("Coffee_QR_Bezel", nectaCol.transform, new Vector3(0f, 0.28f, -0.035f), new Vector3(0.32f, 0.26f, 0.02f), matBezel);
        GameObject coffeeQrObj = CreateBox("Coffee_Display_QR", nectaCol.transform, new Vector3(0f, 0.28f, -0.050f), new Vector3(0.26f, 0.22f, 0.01f), matQR);
        archMgr.coffeeQrRenderer = coffeeQrObj.GetComponent<Renderer>();

        // Ranura de monedas con sticker de instrucciones
        CreateBox("Necta_Coin_Slot", nectaCol.transform, new Vector3(0f, 0.06f, -0.035f), new Vector3(0.18f, 0.04f, 0.02f), matBezel);
        Create3DText("Necta_Coin_Lbl", nectaCol.transform, new Vector3(0f, 0.10f, -0.045f), "MONEDAS", 0.010f, Color.yellow, TextAlignment.Center);

        // Cajetín circular inferior con sticker amarillo y negro "CAMBIO Y DEVOLUCIÓN"
        CreateBox("Necta_Change_Plate", nectaCol.transform, new Vector3(0f, -0.75f, -0.035f), new Vector3(0.28f, 0.22f, 0.03f), matBezel);
        Create3DText("Necta_Change_Sticker", nectaCol.transform, new Vector3(0f, -0.68f, -0.055f), "CAMBIO Y\nDEVOLUCIÓN", 0.010f, Color.yellow, TextAlignment.Center);

        GameObject changeHole = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        changeHole.name = "Coin_Return_Hole";
        changeHole.transform.SetParent(nectaCol.transform, false);
        changeHole.transform.localPosition = new Vector3(0f, -0.80f, -0.045f);
        changeHole.transform.localScale = new Vector3(0.11f, 0.02f, 0.11f);
        changeHole.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
        AssignMaterial(changeHole, matCoffeeChassis);
    }
    #endregion

    #region 4. GROG Universal Edge & Machine Adapter
    private static void BuildUniversalEdgeAndAdapters(Transform parent, MDBArchitectureManager archMgr, Material matEdge, Material matAdapter, Material matMdbCable)
    {
        GameObject esp32 = new GameObject("GROG_EdgeController_ESP32");
        esp32.transform.SetParent(parent, false);
        esp32.transform.localPosition = new Vector3(-0.35f, 0f, 0f);

        CreateBox("ESP32_Chassis", esp32.transform, Vector3.zero, new Vector3(0.55f, 0.65f, 0.22f), matEdge);

        GameObject ant = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        ant.name = "Antenna_IoT";
        ant.transform.SetParent(esp32.transform, false);
        ant.transform.localPosition = new Vector3(0f, 0.44f, 0f);
        ant.transform.localScale = new Vector3(0.025f, 0.14f, 0.025f);
        AssignMaterial(ant, matEdge);

        CreateSphere("LED_Pwr", esp32.transform, new Vector3(-0.16f, 0.22f, -0.115f), new Vector3(0.025f, 0.025f, 0.025f), matMdbCable);
        CreateSphere("LED_MQTT", esp32.transform, new Vector3(0f, 0.22f, -0.115f), new Vector3(0.025f, 0.025f, 0.025f), matMdbCable);
        CreateSphere("LED_AI", esp32.transform, new Vector3(0.16f, 0.22f, -0.115f), new Vector3(0.025f, 0.025f, 0.025f), matMdbCable);

        Create3DText("Edge_Title", esp32.transform, new Vector3(0f, 0.08f, -0.13f), "GROG UNIVERSAL EDGE", 0.018f, Color.cyan, TextAlignment.Center);
        Create3DText("Edge_Sub", esp32.transform, new Vector3(0f, 0.01f, -0.13f), "ESP32 IoT Core • TLS 1.3 • MQTT/WSS", 0.011f, Color.white, TextAlignment.Center);

        GameObject adapter = new GameObject("GROG_Universal_Machine_Adapter");
        adapter.transform.SetParent(parent, false);
        adapter.transform.localPosition = new Vector3(0.35f, 0f, 0f);

        CreateBox("Adapter_PCB", adapter.transform, Vector3.zero, new Vector3(0.55f, 0.65f, 0.20f), matAdapter);
        Create3DText("Adapter_Title", adapter.transform, new Vector3(0f, 0.24f, -0.11f), "UNIVERSAL MACHINE ADAPTER", 0.016f, Color.black, TextAlignment.Center);

        string[] ifaces = new string[] { "[MDB LEVEL 3 (Vending)]", "[PULSE (Arcade/Locker)]", "[RELAY / SERIAL (Cooler/Coffee)]", "[PROPRIETARY]" };
        float[] ifaceY = new float[] { 0.12f, 0.02f, -0.08f, -0.18f };
        for (int i = 0; i < ifaces.Length; i++)
        {
            CreateBox($"Port_Box_{i}", adapter.transform, new Vector3(0f, ifaceY[i], -0.102f), new Vector3(0.50f, 0.08f, 0.015f), matEdge);
            Create3DText($"Port_Txt_{i}", adapter.transform, new Vector3(0f, ifaceY[i], -0.12f), ifaces[i], 0.011f, (i == 0 ? Color.cyan : Color.white), TextAlignment.Center);
        }

        CreateBox("Interconnect", parent, Vector3.zero, new Vector3(0.18f, 0.06f, 0.04f), matEdge);
    }
    #endregion

    #region 5. Subsistema MDB (VMC y Periféricos)
    private static void BuildMDBSubsystem(Transform parent, MDBArchitectureManager archMgr, Material matPcb, Material matMdbCable)
    {
        GameObject vmcObj = new GameObject("VMC_Master_Board");
        vmcObj.transform.SetParent(parent, false);
        vmcObj.transform.localPosition = new Vector3(0.55f, 1.40f, 0.28f);

        CreateBox("VMC_PCB", vmcObj.transform, Vector3.zero, new Vector3(0.44f, 0.65f, 0.02f), matPcb);
        CreateBox("VMC_MCU", vmcObj.transform, new Vector3(0f, 0.05f, -0.018f), new Vector3(0.15f, 0.15f, 0.018f), matPcb);

        Create3DText("VMC_Title", vmcObj.transform, new Vector3(0f, 0.38f, -0.03f), "VMC (Vending Machine Controller)", 0.016f, Color.cyan, TextAlignment.Center);
        Create3DText("VMC_Role", vmcObj.transform, new Vector3(0f, 0.33f, -0.03f), "[MDB MASTER • 9600 BAUD]", 0.012f, Color.white, TextAlignment.Center);

        GameObject coinChanger = new GameObject("MDB_Coin_Changer");
        coinChanger.transform.SetParent(parent, false);
        coinChanger.transform.localPosition = new Vector3(0.60f, 0.85f, -0.15f);
        CreateBox("Coin_Box", coinChanger.transform, Vector3.zero, new Vector3(0.22f, 0.40f, 0.26f), matPcb);
        Create3DText("Coin_Text", coinChanger.transform, new Vector3(0f, 0.25f, -0.14f), "COIN CHANGER (MDB)\n0x08 Bidirectional", 0.011f, Color.yellow, TextAlignment.Center);

        GameObject billVal = new GameObject("MDB_Bill_Validator");
        billVal.transform.SetParent(parent, false);
        billVal.transform.localPosition = new Vector3(0.60f, 1.25f, -0.15f);
        CreateBox("Bill_Box", billVal.transform, Vector3.zero, new Vector3(0.24f, 0.26f, 0.30f), matPcb);
        Create3DText("Bill_Text", billVal.transform, new Vector3(0f, 0.17f, -0.16f), "BILL VALIDATOR (MDB)\n0x30 Escrow Control", 0.011f, Color.yellow, TextAlignment.Center);

        GameObject cashless = new GameObject("MDB_Cashless_Terminal");
        cashless.transform.SetParent(parent, false);
        cashless.transform.localPosition = new Vector3(0.60f, 1.75f, -0.35f);
        CreateBox("Cashless_Box", cashless.transform, Vector3.zero, new Vector3(0.26f, 0.20f, 0.14f), matPcb);
        Create3DText("Cashless_Text", cashless.transform, new Vector3(0f, 0.15f, -0.09f), "CASHLESS MDB LEVEL 3\n0x10 Periph Interface", 0.011f, Color.green, TextAlignment.Center);
    }
    #endregion

    #region 6. Plataforma Cloud & Proof of Service
    private static void BuildCloudPlatform(Transform parent, MDBArchitectureManager archMgr, Material matCard, Material matProofIdle)
    {
        CreateBox("Cloud_Plate", parent, Vector3.zero, new Vector3(4.5f, 1.9f, 0.10f), matCard);
        Create3DText("Cloud_Title", parent, new Vector3(0f, 0.78f, -0.08f), "GROG CLOUD DISTRIBUTED PLATFORM", 0.026f, Color.cyan, TextAlignment.Center);

        string[] services = new string[]
        {
            "Payment Gateway (SimuPay / Bank)", "Transaction Orchestrator",
            "Proof of Service Engine", "Zero-Loss Refund & Reconciliation",
            "Fleet Telemetry Registry", "Multi-Machine Inventory Engine",
            "AI Predictive Core", "HMAC Audit & Security"
        };

        float[] svcX = new float[] { -1.6f, -0.55f, 0.55f, 1.6f };
        float[] svcY = new float[] { 0.36f, -0.18f };

        int sIdx = 0;
        for (int r = 0; r < 2; r++)
        {
            for (int c = 0; c < 4; c++)
            {
                Vector3 pos = new Vector3(svcX[c], svcY[r], -0.06f);
                CreateBox($"Svc_{sIdx}", parent, pos, new Vector3(0.95f, 0.36f, 0.04f), matCard);
                Create3DText($"Svc_Lbl_{sIdx}", parent, pos + new Vector3(0f, 0f, -0.035f), services[sIdx], 0.011f, Color.white, TextAlignment.Center);
                sIdx++;
            }
        }

        GameObject proofBadge = CreateBox("Proof_Badge", parent, new Vector3(0f, -0.68f, -0.12f), new Vector3(4.1f, 0.34f, 0.06f), matProofIdle);
        archMgr.proofOfServiceBadge = proofBadge.GetComponent<Renderer>();

        Create3DText("Proof_Badge_Title", parent, new Vector3(0f, -0.62f, -0.17f), "PROOF OF SERVICE — VERIFICACIÓN FÍSICA MULTI-EVIDENCIA", 0.022f, Color.white, TextAlignment.Center);
        Create3DText("Proof_Badge_Sub", parent, new Vector3(0f, -0.74f, -0.17f), "Liquidación Financiera Condicionada a Evidencia Física de Entrega (HC-SR04, Caldera, Sensores Ópticos)", 0.012f, Color.yellow, TextAlignment.Center);
    }
    #endregion

    #region 7. Digital Twin & AI Engine
    private static void BuildDigitalTwinAndAI(Transform parent, MDBArchitectureManager archMgr, Material matTwinHolo, Material matAiCore)
    {
        CreateBox("Twin_Chassis", parent, new Vector3(0f, 0f, 0f), new Vector3(2.6f, 2.8f, 0.06f), matTwinHolo);
        Create3DText("Twin_Title", parent, new Vector3(0f, 1.25f, -0.06f), "GROG CONTROL CENTER & DIGITAL TWIN", 0.022f, Color.cyan, TextAlignment.Center);

        string streamContent =
            "• FLOTA CONECTADA: VENDING-01 | COOLER-01 | COFFEE-01 (ONLINE)\n" +
            "• TEMPERATURAS: COOLER: 4.2 °C | COFFEE: 92.4 °C (9.2 BAR)\n" +
            "• INTERFAZ INDUSTRIAL: MDB LEVEL 3 (9600 BAUD) + ADAPTADOR MODULAR\n" +
            "• SENSOR HC-SR04: 32.5 cm (EN REPOSO) | DERIVA: 0.0%\n" +
            "• INVENTARIO TOTAL: 84% DISPONIBLE | 0 RESERVADOS | 100% AUDITADO\n" +
            "• LATENCIA UPLINK CLOUD: 34 ms (WSS/TLS ENCRIPTADO)\n" +
            "• ÍNDICE DE SALUD OPERATIVA: 99.4% (ÓPTIMO)";

        Create3DText("Twin_Body", parent, new Vector3(0f, 0.25f, -0.06f), streamContent, 0.013f, Color.white, TextAlignment.Center);

        GameObject aiRoot = new GameObject("GROG_AI_Engine");
        aiRoot.transform.SetParent(parent, false);
        aiRoot.transform.localPosition = new Vector3(0f, 2.5f, 0f);

        GameObject aiCore = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        aiCore.name = "AI_Neural_Core";
        aiCore.transform.SetParent(aiRoot.transform, false);
        aiCore.transform.localScale = new Vector3(0.65f, 0.65f, 0.65f);
        AssignMaterial(aiCore, matAiCore);

        Create3DText("AI_Title", aiRoot.transform, new Vector3(0f, 0.52f, 0f), "GROG AI ENGINE (UPPER INTELLIGENCE TIER)", 0.022f, new Color(0.9f, 0.3f, 1.0f), TextAlignment.Center);
    }
    #endregion

    #region Conexión de Buses de Datos
    private static void SetupDataBusCables(Transform parent, MDBArchitectureManager archMgr, Material matMdbCable)
    {
        // 1. Bus MDB (VMC -> Periféricos -> Machine Adapter)
        GameObject mdbBusGo = new GameObject("MDB_Bus_DataHighway");
        mdbBusGo.transform.SetParent(parent, false);
        LineRenderer lrMdb = mdbBusGo.AddComponent<LineRenderer>();
        lrMdb.startWidth = 0.035f;
        lrMdb.endWidth = 0.035f;
        lrMdb.material = matMdbCable;
        lrMdb.useWorldSpace = true;
        lrMdb.positionCount = 6;
        lrMdb.SetPositions(new Vector3[]
        {
            new Vector3(-3.25f, 1.40f, 0.28f),   // VMC
            new Vector3(-3.20f, 0.85f, -0.15f),  // Coin Changer
            new Vector3(-3.20f, 1.25f, -0.15f),  // Bill Validator
            new Vector3(-3.20f, 1.75f, -0.35f),  // Cashless
            new Vector3(-1.80f, 2.40f, 0f),      // Tránsito
            new Vector3(-1.45f, 3.20f, 0.4f)     // Machine Adapter MDB Port
        });
        archMgr.mdbBusLine = lrMdb;

        // 2. Uplink IoT Edge Gateway -> GROG Cloud
        GameObject edgeCloudGo = new GameObject("IoT_Edge_To_Cloud_DataLink");
        edgeCloudGo.transform.SetParent(parent, false);
        LineRenderer lrCloud = edgeCloudGo.AddComponent<LineRenderer>();
        lrCloud.startWidth = 0.040f;
        lrCloud.endWidth = 0.040f;
        lrCloud.material = matMdbCable;
        lrCloud.useWorldSpace = true;
        lrCloud.positionCount = 3;
        lrCloud.SetPositions(new Vector3[]
        {
            new Vector3(-2.15f, 3.65f, 0.4f),    // ESP32 Antenna
            new Vector3(-2.15f, 4.4f, 0.3f),
            new Vector3(0f, 4.4f, 0.2f)          // Cloud Base
        });
        archMgr.edgeToCloudLine = lrCloud;

        // 3. Sync Cloud -> Digital Twin
        GameObject cloudTwinGo = new GameObject("Cloud_To_DigitalTwin_SyncLink");
        cloudTwinGo.transform.SetParent(parent, false);
        LineRenderer lrTwin = cloudTwinGo.AddComponent<LineRenderer>();
        lrTwin.startWidth = 0.035f;
        lrTwin.endWidth = 0.035f;
        lrTwin.material = matMdbCable;
        lrTwin.useWorldSpace = true;
        lrTwin.positionCount = 3;
        lrTwin.SetPositions(new Vector3[]
        {
            new Vector3(0f, 4.4f, 0.2f),
            new Vector3(1.8f, 4.4f, 0.3f),
            new Vector3(1.8f, 3.8f, 0.4f)
        });
        archMgr.cloudToTwinLine = lrTwin;
    }
    #endregion

    #region Banner Académico
    private static void CreateAcademicBanner(Transform parent)
    {
        GameObject banner = new GameObject("Academic_Header_FUNTEC2026");
        banner.transform.SetParent(parent, false);
        banner.transform.position = new Vector3(0f, 6.4f, 0f);

        Create3DText("Funtec_Title", banner.transform, Vector3.zero, "FUNTEC 2026: PLATAFORMA UNIVERSAL GROG — DIGITAL TWIN MULTI-MÁQUINA", 0.036f, Color.white, TextAlignment.Center);
        Create3DText("Funtec_Subtitle", banner.transform, new Vector3(0f, -0.22f, 0f), "Infraestructura IoT + FinTech: Expendedora de Snacks (VENDING-01) • Refrigerador de Bebidas (COOLER-01) • Cafetera (COFFEE-01)", 0.016f, Color.yellow, TextAlignment.Center);
    }
    #endregion

    #region Utilidades 3D y Shaders
    private static Mesh CreateHelicalSpringMesh(float coilRadius = 0.075f, float wireRadius = 0.009f, float length = 0.38f, int turns = 5, int segmentsPerTurn = 36, int crossSectionSegments = 8)
    {
        Mesh mesh = new Mesh();
        mesh.name = "HelicalSpring";

        int totalSteps = turns * segmentsPerTurn;
        int ringCount = totalSteps + 1;
        int vertsPerRing = crossSectionSegments;
        int totalVerts = ringCount * vertsPerRing;

        Vector3[] vertices = new Vector3[totalVerts];
        Vector2[] uvs = new Vector2[totalVerts];
        int[] triangles = new int[totalSteps * crossSectionSegments * 6];

        for (int i = 0; i < ringCount; i++)
        {
            float progress = (float)i / totalSteps;
            float theta = progress * turns * Mathf.PI * 2f;
            float z = (progress - 0.5f) * length;

            Vector3 center = new Vector3(Mathf.Cos(theta) * coilRadius, Mathf.Sin(theta) * coilRadius, z);
            Vector3 tangent = new Vector3(-Mathf.Sin(theta) * coilRadius, Mathf.Cos(theta) * coilRadius, length / (turns * Mathf.PI * 2f)).normalized;
            Vector3 normal = new Vector3(Mathf.Cos(theta), Mathf.Sin(theta), 0f).normalized;
            Vector3 binormal = Vector3.Cross(tangent, normal).normalized;

            for (int j = 0; j < crossSectionSegments; j++)
            {
                float phi = (float)j / crossSectionSegments * Mathf.PI * 2f;
                Vector3 offset = (Mathf.Cos(phi) * normal + Mathf.Sin(phi) * binormal) * wireRadius;
                int vertIndex = i * vertsPerRing + j;
                vertices[vertIndex] = center + offset;
                uvs[vertIndex] = new Vector2((float)j / crossSectionSegments, progress * turns);
            }
        }

        int triIndex = 0;
        for (int i = 0; i < totalSteps; i++)
        {
            int ring1 = i * vertsPerRing;
            int ring2 = (i + 1) * vertsPerRing;

            for (int j = 0; j < crossSectionSegments; j++)
            {
                int nextJ = (j + 1) % crossSectionSegments;
                int a = ring1 + j;
                int b = ring2 + j;
                int c = ring2 + nextJ;
                int d = ring1 + nextJ;

                triangles[triIndex++] = a;
                triangles[triIndex++] = b;
                triangles[triIndex++] = c;

                triangles[triIndex++] = a;
                triangles[triIndex++] = c;
                triangles[triIndex++] = d;
            }
        }

        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.uv = uvs;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();
        return mesh;
    }

    private static void SaveMeshAsset(Mesh mesh, string path)
    {
        Mesh existing = AssetDatabase.LoadAssetAtPath<Mesh>(path);
        if (existing == null)
        {
            AssetDatabase.CreateAsset(mesh, path);
        }
        else
        {
            existing.Clear();
            EditorUtility.CopySerialized(mesh, existing);
            AssetDatabase.SaveAssets();
        }
    }

    private static void SetupEnvironment()
    {
        GameObject camObj = new GameObject("Main Camera");
        camObj.tag = "MainCamera";
        Camera cam = camObj.AddComponent<Camera>();
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color(0.06f, 0.08f, 0.12f);
        cam.fieldOfView = 50f;
        camObj.AddComponent<AudioListener>();
        camObj.transform.position = new Vector3(0f, 3.4f, -7.5f);
        camObj.transform.LookAt(new Vector3(0f, 2.2f, 0f));

        GameObject lightObj = new GameObject("Directional Light");
        Light dirLight = lightObj.AddComponent<Light>();
        dirLight.type = LightType.Directional;
        dirLight.intensity = 1.35f;
        dirLight.color = new Color(1.0f, 0.98f, 0.95f);
        lightObj.transform.rotation = Quaternion.Euler(42f, -32f, 0f);

        GameObject fillLightObj = new GameObject("Tech_Fill_Light");
        Light fillLight = fillLightObj.AddComponent<Light>();
        fillLight.type = LightType.Directional;
        fillLight.intensity = 0.55f;
        fillLight.color = new Color(0.1f, 0.5f, 0.9f);
        fillLightObj.transform.rotation = Quaternion.Euler(-25f, 140f, 0f);
    }

    private static TextMesh Create3DText(string name, Transform parent, Vector3 localPos, string text, float characterSize, Color color, TextAlignment alignment)
    {
        GameObject textObj = new GameObject(name);
        textObj.transform.SetParent(parent, false);
        textObj.transform.localPosition = localPos;
        textObj.transform.localRotation = Quaternion.identity;
        textObj.transform.localScale = Vector3.one;

        TextMesh tm = textObj.AddComponent<TextMesh>();
        tm.text = text;
        tm.fontSize = 0;
        tm.characterSize = characterSize;
        tm.anchor = TextAnchor.MiddleCenter;
        tm.alignment = alignment;
        tm.color = color;

        try
        {
            Font font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (font != null)
            {
                tm.font = font;
                MeshRenderer mr = textObj.GetComponent<MeshRenderer>();
                if (mr != null) mr.sharedMaterial = font.material;
            }
        }
        catch { }

        return tm;
    }

    private static GameObject CreateBox(string name, Transform parent, Vector3 localPos, Vector3 localScale, Material material)
    {
        GameObject box = GameObject.CreatePrimitive(PrimitiveType.Cube);
        box.name = name;
        box.transform.SetParent(parent, false);
        box.transform.localPosition = localPos;
        box.transform.localScale = localScale;
        AssignMaterial(box, material);
        return box;
    }

    private static GameObject CreateSphere(string name, Transform parent, Vector3 localPos, Vector3 localScale, Material material)
    {
        GameObject sph = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        sph.name = name;
        sph.transform.SetParent(parent, false);
        sph.transform.localPosition = localPos;
        sph.transform.localScale = localScale;
        AssignMaterial(sph, material);
        return sph;
    }

    private static Material GetOrCreateMaterial(string name, Color color, float smoothness, float metallic, string preferredShader = null)
    {
        string path = $"{MaterialsFolder}/{name}.mat";
        Material mat = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (mat == null)
        {
            Shader shader = null;
            if (!string.IsNullOrEmpty(preferredShader))
            {
                shader = Shader.Find(preferredShader);
            }
            if (shader == null)
            {
                shader = Shader.Find("Standard") ?? Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Mobile/Diffuse");
            }
            mat = new Material(shader);
            mat.name = name;
            mat.color = color;
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", smoothness);
            if (mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness", smoothness);
            if (mat.HasProperty("_Metallic")) mat.SetFloat("_Metallic", metallic);

            AssetDatabase.CreateAsset(mat, path);
        }
        return mat;
    }

    private static Material GetOrCreateEmissiveMaterial(string name, Color color, float emissionIntensity)
    {
        string path = $"{MaterialsFolder}/{name}.mat";
        Material mat = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (mat == null)
        {
            Shader shader = Shader.Find("Standard") ?? Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Mobile/Diffuse");
            mat = new Material(shader);
            mat.name = name;
            mat.color = color;
            if (mat.HasProperty("_EmissionColor"))
            {
                mat.EnableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", color * emissionIntensity);
            }
            AssetDatabase.CreateAsset(mat, path);
        }
        return mat;
    }

    private static Material CreateGlassMaterial(string name, Color glassColor)
    {
        string path = $"{MaterialsFolder}/{name}.mat";
        Material mat = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (mat == null)
        {
            Shader standardShader = Shader.Find("Standard") ?? Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Mobile/Diffuse");
            mat = new Material(standardShader);
            mat.name = name;
            mat.color = glassColor;

            if (mat.shader.name == "Standard")
            {
                mat.SetFloat("_Mode", 3);
                mat.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                mat.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                mat.SetInt("_ZWrite", 0);
                mat.DisableKeyword("_ALPHATEST_ON");
                mat.EnableKeyword("_ALPHABLEND_ON");
                mat.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                mat.renderQueue = 3000;
                mat.SetFloat("_Glossiness", 0.95f);
                mat.SetFloat("_Metallic", 0.1f);
            }

            AssetDatabase.CreateAsset(mat, path);
        }
        return mat;
    }

    private static void AssignMaterial(GameObject go, Material mat)
    {
        if (mat != null && go.TryGetComponent<Renderer>(out var renderer))
        {
            renderer.sharedMaterial = mat;
        }
    }
    #endregion
}
