import 'map_picker_screen.dart';
import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/purchase_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../../controllers/admin_dashboard_controller.dart';
import '../../widgets/animated_grog_frog.dart';
import '../auth/login_screen.dart';
import '../purchase/payment_confirmation_screen.dart';
import '../purchase/qr_scanner_screen.dart';
import '../purchase/nfc_vending_screen.dart';
import '../wallet/history_screen.dart';
import '../wallet/transfer_screen.dart';
import '../../../domain/entities/auth_session.dart';
import '../../controllers/notification_controller.dart';
import '../notifications/notification_screens.dart';
import 'admin_panel_tab.dart';
import 'audit_logs_tab.dart';
import 'devops_panel_tab.dart';

// Cache to prevent jank when scrolling tabs
final Map<String, Uint8List> _base64Cache = {};

Uint8List _getDecodedBytes(String base64Str) {
  if (_base64Cache.containsKey(base64Str)) {
    return _base64Cache[base64Str]!;
  }
  try {
    String cleanStr = base64Str.trim();
    if (cleanStr.contains(',')) {
      cleanStr = cleanStr.split(',').last.trim();
    }
    cleanStr = cleanStr.replaceAll(RegExp(r'\s+'), '');
    final bytes = base64Decode(cleanStr);
    if (_base64Cache.length > 50) _base64Cache.clear(); // simple eviction
    _base64Cache[base64Str] = bytes;
    return bytes;
  } catch (_) {
    return Uint8List(0);
  }
}


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<Uri>? _linkSubscription;
  bool _nfcListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _initNfcListener();
      _checkInitialLink();
    });
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });
  }

  Future<void> _checkInitialLink() async {
    try {
      final initialUri = await AppLinks().getInitialLink();
      if (initialUri != null) {
        _handleIncomingUri(initialUri);
      }
    } catch (_) {}
  }

  void _handleIncomingUri(Uri uri) {
    if (uri.scheme == 'grog' && uri.host == 'wallet' && uri.path == '/callback') {
      final linkedEmail = uri.queryParameters['email'];
      _load(linkWallet: true, linkedEmail: linkedEmail);
    } else if (uri.scheme == 'grog' && uri.host == 'vending') {
      String machineId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'MACHINE-001';
      final token = uri.queryParameters['token'];
      if (mounted) {
        _showNfcMachinePanel(machineId, token: token);
      }
    }
  }

  Future<String?> _extractNfcPayload(NfcTag tag) async {
    NdefMessage? message;
    final ndefAndroid = NdefAndroid.from(tag);
    if (ndefAndroid != null) {
      message = ndefAndroid.cachedNdefMessage ?? await ndefAndroid.getNdefMessage();
    } else {
      final ndefIos = NdefIos.from(tag);
      if (ndefIos != null) {
        message = ndefIos.cachedNdefMessage ?? await ndefIos.readNdef();
      }
    }

    if (message != null) {
      for (final record in message.records) {
        if (record.payload.isNotEmpty) {
          try {
            if (record.typeNameFormat == TypeNameFormat.wellKnown) {
              final langCodeLen = record.payload.first & 0x3F;
              if (record.payload.length > langCodeLen + 1) {
                return utf8.decode(record.payload.sublist(langCodeLen + 1));
              }
            }
            return utf8.decode(record.payload);
          } catch (_) {}
        }
      }
    }
    return null;
  }

  Future<void> _initNfcListener() async {
    final prefs = await SharedPreferences.getInstance();
    final isNfcEnabled = prefs.getBool('nfc_enabled') ?? false;

    if (!isNfcEnabled) {
      if (_nfcListening) {
        try {
          await NfcManager.instance.stopSession();
        } catch (_) {}
        _nfcListening = false;
      }
      return;
    }

    if (_nfcListening) return;

    try {
      final isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) return;

      _nfcListening = true;
      NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final payload = await _extractNfcPayload(tag);

            if (payload != null && payload.trim().isNotEmpty) {
              final cleanPayload = payload.trim();
              String machineId = cleanPayload;
              String? token;
              if (cleanPayload.contains('/init/')) {
                final parts = cleanPayload.split('/init/');
                machineId = parts.last.split('?').first.trim();
              } else if (cleanPayload.startsWith('grog://vending/')) {
                final uri = Uri.tryParse(cleanPayload);
                if (uri != null) {
                  machineId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'MACHINE-001';
                  token = uri.queryParameters['token'];
                } else {
                  machineId = cleanPayload.replaceFirst('grog://vending/', '').split('?').first.trim();
                }
              } else if (cleanPayload.contains('machine_id=')) {
                final uri = Uri.tryParse(cleanPayload);
                if (uri != null && uri.queryParameters.containsKey('machine_id')) {
                  machineId = uri.queryParameters['machine_id']!;
                  token = uri.queryParameters['token'];
                }
              }

              if (machineId.isNotEmpty && mounted) {
                _showNfcMachinePanel(machineId, token: token);
              }
            }
          } catch (e) {
            debugPrint('Error decodificando NFC: $e');
          }
        },
      ).catchError((e) {
        _nfcListening = false;
        debugPrint('Error en sesión NFC: $e');
      });
    } catch (e) {
      _nfcListening = false;
      debugPrint('NFC no disponible: $e');
    }
  }

  Future<void> _showNfcMachinePanel(String machineId, {String? token}) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NfcVendingScreen(
          machineId: machineId,
          token: token,
        ),
      ),
    );
  }
  Future<void> _load({bool linkWallet = false, String? linkedEmail}) async {
    final auth = context.read<AuthController>();
    final profile = context.read<ProfileController>();
    final wallet = context.read<WalletController>();
    final admin = context.read<AdminDashboardController>();
    final session = auth.session;
    if (session == null) return;

    if (linkWallet && linkedEmail != null) {
      await auth.linkSimupay(linkedEmail);
      await wallet.load(linkedEmail);
      return;
    }

    final targetEmail = session.simupayEmail ?? session.email;
    final role = session.role.toUpperCase();

    // Cargar en paralelo perfil, billetera, notificaciones y banner/stats
    await Future.wait([
      profile.load(session.email),
      wallet.load(targetEmail),
      if (context.mounted)
        context.read<NotificationController>().loadNotifications(session.email),
      if (role == 'ADMIN' || role == 'DEVOPS')
        admin.loadStats()
      else
        admin.loadBannerOnly(),
    ]);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    if (_nfcListening) {
      NfcManager.instance.stopSession().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = context.watch<ProfileController>();
    final wallet = context.watch<WalletController>();
    final session = auth.session;
    if (session == null) return const LoginScreen();

    final walletInfo = wallet.wallet;
    final linked = walletInfo?.linked ?? false;
    final isAdmin = session.role == 'ADMIN';
    final isDevOps = session.role == 'DEVOPS';

    return DefaultTabController(
      length: isAdmin ? 5 : (isDevOps ? 2 : 1),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedGrogFrog(size: 32),
              SizedBox(width: 8),
              Text(
                'GROG',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          actions: [
            Consumer<NotificationController>(
              builder: (context, ctrl, _) => Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationListScreen()),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined, color: Colors.black54),
                  ),
                  if (ctrl.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${ctrl.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          bottom:
              isAdmin
                  ? const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Mi Billetera', icon: Icon(Icons.wallet)),
                      Tab(text: 'Ventas', icon: Icon(Icons.analytics)),
                      Tab(text: 'Máquinas', icon: Icon(Icons.grid_view)),
                      Tab(text: 'Publicidad', icon: Icon(Icons.campaign)),
                      Tab(text: 'Auditoría', icon: Icon(Icons.security)),
                    ],
                    labelColor: Color(0xFF4F46E5),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF4F46E5),
                  )
                  : (isDevOps
                      ? const TabBar(
                          tabs: [
                            Tab(text: 'IoT Telemetría', icon: Icon(Icons.sensors)),
                            Tab(text: 'Máquinas', icon: Icon(Icons.settings_remote)),
                          ],
                          labelColor: Color(0xFF4F46E5),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Color(0xFF4F46E5),
                        )
                      : null),
        ),
        body: isAdmin
            ? TabBarView(
                children: [
                  _buildMainDashboard(context, profile, wallet, session, linked, walletInfo),
                  _buildAdminSalesTab(context),
                  _buildAdminMachinesTab(context),
                  _buildAdminBannerTab(context),
                  const AuditLogsTab(),
                ],
              )
            : (isDevOps
                ? TabBarView(
                    children: [
                      const DevOpsPanelTab(),
                      _buildAdminMachinesTab(context),
                    ],
                  )
                : _buildMainDashboard(context, profile, wallet, session, linked, walletInfo)),
      ),
    );
  }

  Widget _buildAdminSalesTab(BuildContext context) {
    return const AdminPanelTab();
  }

  Widget _buildAdminMachinesTab(BuildContext context) {
    final controller = context.watch<AdminDashboardController>();
    final auth = context.watch<AuthController>();
    final sessionEmail = auth.session?.email ?? 'admin@grog.com';

    if (controller.machines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.developer_board_off_rounded, size: 52, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No hay máquinas vinculadas en tu cuenta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Activa el Modo Instalador en la máquina y vincúlala con su PIN.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => _showClaimMachineDialog(context, controller, sessionEmail),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Vincular Máquina (PIN / QR)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // BANNER HEADER DE GESTIÓN Y VINCULACIÓN
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF312E81).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flota de Expendedoras',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Vincula terminales virtuales (Unity) o físicas (ESP32) con PIN seguro de 6 dígitos.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showClaimMachineDialog(context, controller, sessionEmail),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Vincular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),

        ...controller.machines.map((machine) {
          final machineId = machine['id'];
          final inventory = controller.inventories[machineId] ?? [];
          final isVirtual = machine['environment'] == 'SIMULATED';
          final mType = machine['machine_type'] ?? 'SNACK_VENDING';
          String typeChipLabel = '🍿 Snacks';
          if (mType == 'COOLER_DRINKS') typeChipLabel = '🥤 Bebidas';
          if (mType == 'COFFEE_MACHINE') typeChipLabel = '☕ Café';

          return Card(
            margin: const EdgeInsets.only(bottom: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isVirtual ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
                        child: Icon(
                          isVirtual ? Icons.videogame_asset_rounded : Icons.bolt_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              machine['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: $machineId | Modelo: ${machine['brand_model'] ?? 'Universal'}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 6),
                            // BADGES: VIRTUAL/FÍSICA, TIPO Y PROTOCOLO
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isVirtual ? const Color(0xFFEEF2FF) : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isVirtual ? const Color(0xFFC7D2FE) : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isVirtual ? Icons.tv_rounded : Icons.developer_board_rounded,
                                        size: 11,
                                        color: isVirtual ? const Color(0xFF4338CA) : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isVirtual ? 'VIRTUAL' : 'FÍSICA',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isVirtual ? const Color(0xFF4338CA) : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    typeChipLabel,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Text(
                                    machine['protocol'] ?? 'MDB',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (machine['status'] == 'online' ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (machine['status'] == 'online' ? Colors.green : Colors.grey).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: machine['status'] == 'online' ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              machine['status']?.toString().toUpperCase() ?? 'OFFLINE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: machine['status'] == 'online' ? Colors.green.shade800 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // BARRA HORIZONTAL DE ACCIONES (SOLO ICONOS LIMPIOS)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 1. Foco
                        Builder(builder: (context) {
                          bool isLightOn = controller.machineLights[machineId] ?? false;
                          return IconButton(
                            tooltip: isLightOn ? 'Apagar foco' : 'Encender foco',
                            icon: Icon(
                              isLightOn ? Icons.lightbulb : Icons.lightbulb_outline,
                              color: isLightOn ? Colors.amber : Colors.grey[700],
                              size: 22,
                              shadows: isLightOn ? [const BoxShadow(color: Colors.amber, blurRadius: 10)] : null,
                            ),
                            onPressed: () => controller.toggleLights(machineId),
                          );
                        }),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),
                        // 2. Stats
                        IconButton(
                          tooltip: 'Estadísticas de ventas',
                          icon: const Icon(Icons.bar_chart, color: Colors.orange, size: 22),
                          onPressed: () => _showTopSellersDialog(context, controller, machineId),
                        ),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),
                        // 3. Ubicación
                        IconButton(
                          tooltip: 'Ubicación en mapa',
                          icon: const Icon(Icons.location_on, color: Colors.blue, size: 22),
                          onPressed: () async {
                            final double lat = machine['lat'] != null ? double.tryParse(machine['lat'].toString()) ?? 0 : 0;
                            final double lng = machine['lng'] != null ? double.tryParse(machine['lng'].toString()) ?? 0 : 0;
                            
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapPickerScreen(initialLat: lat, initialLng: lng),
                              ),
                            );
                            
                            if (result != null) {
                              await controller.updateMachineLocation(machineId, result.latitude, result.longitude);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación guardada con éxito')));
                              }
                            }
                          },
                        ),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),
                        // 4. Tuerca / Config
                        IconButton(
                          tooltip: 'Configuración técnica',
                          icon: const Icon(Icons.settings, color: Color(0xFF4F46E5), size: 22),
                          onPressed: () => _showMachineSettingsDialog(context, controller, machineId),
                        ),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),
                        // 5. Desvincular / Reset
                        IconButton(
                          tooltip: 'Desvincular de mi cuenta',
                          icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 22),
                          onPressed: () => _confirmFactoryReset(context, controller, machineId, machine['name'] ?? ''),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Productos',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Añadir Slot',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () => _showAddSlotDialog(context, controller, machineId),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: inventory.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text('No hay slots configurados.'),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: inventory.length,
                          itemBuilder: (context, i) {
                            final item = inventory[i];
                            final isEnabled = item['is_enabled'] ?? true;
                            final type = item['slot_type'] ?? 'soda';

                            int stock = item['stock'] ?? 0;
                            bool realEnabled = isEnabled && stock > 0;
                            
                            Widget imageWidget;
                            if (item['image_base64'] != null && item['image_base64'].toString().isNotEmpty) {
                              imageWidget = ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _getDecodedBytes(item['image_base64']),
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                ),
                              );
                            } else {
                              imageWidget = Icon(
                                type == 'soda' ? Icons.local_drink : Icons.fastfood,
                                color: realEnabled ? const Color(0xFF4F46E5) : Colors.grey,
                                size: 30,
                              );
                            }
                            
                            if (!realEnabled) {
                              imageWidget = ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0,      0,      0,      1, 0,
                                ]),
                                child: imageWidget,
                              );
                            }

                            final slotCard = Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: realEnabled ? Colors.white : Colors.grey[200],
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                                border: Border.all(
                                  color: realEnabled
                                      ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                                      : Colors.red.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(child: imageWidget),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Bs. ${item['price']}',
                                        style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (!realEnabled)
                                      const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('AGOTADO', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ),
                            );

                            return DragTarget<int>(
                              onWillAcceptWithDetails: (details) => details.data != i,
                              onAcceptWithDetails: (details) async {
                                final fromIndex = details.data;
                                final toIndex = i;
                                final list = List<dynamic>.from(inventory);
                                final movedItem = list.removeAt(fromIndex);
                                list.insert(toIndex, movedItem);
                                final orderedSlots = list.map((e) => e['slot'].toString()).toList();
                                await controller.reorderSlots(machineId, orderedSlots);
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isTarget = candidateData.isNotEmpty;
                                return LongPressDraggable<int>(
                                  data: i,
                                  feedback: Material(
                                    elevation: 6,
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 80,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFF4F46E5), width: 2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${item['slot']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: InkWell(
                                      onTap: () => _showEditSlotDialog(context, controller, machineId, item),
                                      child: Column(
                                        children: [
                                          Expanded(child: slotCard),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('${item['slot']}: ${item['product_name'] ?? ''}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('Disp: $stock', style: TextStyle(fontSize: 9, color: Colors.grey[700])),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: isTarget ? Border.all(color: Colors.orange, width: 2.5) : null,
                                    ),
                                    child: InkWell(
                                      onTap: () => _showEditSlotDialog(context, controller, machineId, item),
                                      child: Column(
                                        children: [
                                          Expanded(child: slotCard),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${item['slot']}: ${item['product_name'] ?? ''}',
                                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Disp: $stock',
                                              style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showEditSlotDialog(BuildContext context, AdminDashboardController controller, String machineId, dynamic item) {
    final slotCodeController = TextEditingController(text: item['slot'].toString());
    final nameController = TextEditingController(text: (item['product_name'] ?? '').toString());
    final priceController = TextEditingController(text: item['price'].toString());
    final stockController = TextEditingController(text: (item['stock'] ?? 0).toString());
    bool isEnabled = item['is_enabled'] ?? true;
    String slotType = item['slot_type'] ?? 'soda';
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Gestionar Slot ${item['slot']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: slotCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Identificador del Slot',
                    hintText: 'Ej. A1, B2, E1',
                    prefixIcon: Icon(Icons.grid_view),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Producto',
                    hintText: 'Ej. Coca Cola 500ml',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio (Bs.)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad en Stock',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Habilitado'),
                  value: isEnabled,
                  onChanged: (v) => setModalState(() => isEnabled = v),
                ),
                const Text('Tipo de Producto:'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Soda'),
                      selected: slotType == 'soda',
                      onSelected: (v) => setModalState(() => slotType = 'soda'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Snack'),
                      selected: slotType == 'snack',
                      onSelected: (v) => setModalState(() => slotType = 'snack'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      final base64Image = base64Encode(bytes);
                      if (context.mounted) {
                        Navigator.pop(context);
                        await controller.updateSlotImage(machineId, item['slot'], base64Image);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto actualizada')));
                      }
                    }
                  },
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Cambiar foto de producto'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text);
                final stock = int.tryParse(stockController.text);
                final name = nameController.text.trim();
                final newSlot = slotCodeController.text.trim().toUpperCase();

                if (price != null && stock != null) {
                  Navigator.pop(context);
                  await controller.updateSlotDetails(
                    machineId,
                    item['slot'],
                    item['inventory_id'],
                    price,
                    stock,
                    isEnabled,
                    slotType,
                    newProductName: name.isNotEmpty ? name : null,
                    newSlot: newSlot.isNotEmpty ? newSlot : null,
                  );
                  if (context.mounted) {
                    if (controller.error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al guardar: ${controller.error}'), backgroundColor: Colors.red),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Slot $newSlot actualizado con éxito'),
                          backgroundColor: const Color(0xFF4F46E5),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSlotDialog(BuildContext context, AdminDashboardController controller, String machineId) {
    final slotCodeController = TextEditingController();
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '8.0');
    final stockController = TextEditingController(text: '10');
    String slotType = 'soda';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Añadir Nuevo Slot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: slotCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Identificador del Slot',
                    hintText: 'Ej. E1, D2, F3',
                    prefixIcon: Icon(Icons.grid_view),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Producto',
                    hintText: 'Ej. Fanta 500ml',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio (Bs.)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad Inicial en Stock',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tipo de Producto:'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Soda'),
                      selected: slotType == 'soda',
                      onSelected: (v) => setModalState(() => slotType = 'soda'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Snack'),
                      selected: slotType == 'snack',
                      onSelected: (v) => setModalState(() => slotType = 'snack'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final slotCode = slotCodeController.text.trim().toUpperCase();
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text);
                final stock = int.tryParse(stockController.text);

                if (slotCode.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debes especificar un código de slot (ej. E1)')),
                  );
                  return;
                }
                if (price != null && stock != null) {
                  Navigator.pop(context);
                  await controller.createSlot(
                    machineId,
                    slot: slotCode,
                    productName: name.isNotEmpty ? name : 'Producto $slotCode',
                    price: price,
                    stock: stock,
                    slotType: slotType,
                  );
                  if (context.mounted) {
                    if (controller.error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al crear: ${controller.error}'), backgroundColor: Colors.red),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Slot $slotCode creado con éxito'),
                          backgroundColor: const Color(0xFF4F46E5),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Crear Slot'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClaimMachineDialog(BuildContext context, AdminDashboardController controller, String ownerEmail) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF4F46E5), size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vincular Máquina',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Detección automática Virtual o Física',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.blue.shade800, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'En la máquina (Virtual en Unity o Física con ESP32), activa el "Modo Instalador" para generar el PIN de 6 dígitos seguro (válido por 5 minutos).',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      autofocus: true,
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Código PIN o Token QR *',
                        hintText: 'Ej: 894503 o escanea el QR',
                        prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF4F46E5)),
                        suffixIcon: IconButton(
                          tooltip: 'Escanear QR con cámara',
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF4F46E5)),
                          onPressed: () async {
                            final scanned = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                            );
                            if (scanned != null && scanned.trim().isNotEmpty) {
                              setModalState(() {
                                codeController.text = scanned.trim();
                              });
                            }
                          },
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF818CF8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final scanned = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                        );
                        if (scanned != null && scanned.trim().isNotEmpty) {
                          setModalState(() {
                            codeController.text = scanned.trim();
                          });
                        }
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 20),
                      label: const Text('Escanear Código QR con Cámara', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre personalizado (Opcional)',
                        hintText: 'Ej: Expendedora Auditorio Norte',
                        prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final inputCode = codeController.text.trim();
                              if (inputCode.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Por favor ingresa el código PIN o QR')),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                final res = await controller.claimMachine(
                                  codeOrToken: inputCode,
                                  ownerEmail: ownerEmail,
                                  name: nameController.text.trim().isNotEmpty ? nameController.text.trim() : null,
                                );

                                if (bottomCtx.mounted) {
                                  Navigator.pop(bottomCtx);
                                }

                                final machineData = res['machine'] as Map<String, dynamic>? ?? {};
                                final isVirtual = machineData['environment'] == 'SIMULATED';
                                final mType = machineData['machine_type'] ?? 'SNACK_VENDING';
                                String typeLabel = '🍿 Expendedora de Snacks';
                                if (mType == 'COOLER_DRINKS') typeLabel = '🥤 Bebidas Refrigeradas';
                                if (mType == 'COFFEE_MACHINE') typeLabel = '☕ Máquina de Café';

                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (diagCtx) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                        title: const Row(
                                          children: [
                                            Text('🎉 ', style: TextStyle(fontSize: 24)),
                                            Expanded(
                                              child: Text(
                                                '¡Máquina Vinculada!',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              res['message'] ?? 'Máquina registrada con éxito en tu cuenta.',
                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                            ),
                                            const SizedBox(height: 14),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: isVirtual ? const Color(0xFFEEF2FF) : const Color(0xFFFFFBEB),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          isVirtual ? '🎮 Entorno Virtual (Unity)' : '⚡ Hardware Físico (ESP32)',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: isVirtual ? const Color(0xFF4338CA) : const Color(0xFFB45309),
                                                          ),
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      Text(
                                                        machineData['protocol'] ?? 'MDB',
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Equipo: ${machineData['name'] ?? ''}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  Text(
                                                    'Tipo: $typeLabel',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                                  ),
                                                  Text(
                                                    'ID: ${machineData['id']}',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(diagCtx),
                                            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al vincular: ${e.toString().replaceAll('Exception:', '')}'),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Verificar y Vincular a mi Cuenta',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmFactoryReset(BuildContext context, AdminDashboardController controller, String machineId, String machineName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Desvincular Máquina',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Deseas desvincular $machineName ($machineId) de tu cuenta?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Text(
                'Al desvincularla, la máquina se liberará de la nube. Cualquier persona podrá pulsar su botón físico iluminado de reset para volver a vincularla a otra cuenta.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await controller.factoryResetMachine(machineId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Máquina $machineName desvinculada exitosamente')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Desvincular y Liberar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showMachineSettingsDialog(BuildContext context, AdminDashboardController controller, String machineId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: controller.getMachineConfig(machineId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final config = snapshot.data ?? {};
            int currentTtl = (config['code_ttl'] as num?)?.toInt() ?? 45;
            final ttlController = TextEditingController(text: currentTtl.toString());
            final ssidController = TextEditingController(text: config['wifi_ssid'] ?? '');
            final passController = TextEditingController(text: config['wifi_password'] ?? '');
            final serverController = TextEditingController(text: config['server_ip'] ?? '');
            bool isSaving = false;

            return StatefulBuilder(
              builder: (context, setStateModal) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.settings, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ajustes: $machineId',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rotación de Código PIN (TTL)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: ttlController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Segundos de expiración (TTL)',
                            border: OutlineInputBorder(),
                            suffixText: 'seg',
                            prefixIcon: Icon(Icons.timelapse),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [30, 45, 60, 90, 120].map((s) {
                            return ActionChip(
                              label: Text('$s s'),
                              onPressed: () {
                                setStateModal(() {
                                  ttlController.text = s.toString();
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const Divider(height: 24),
                        // TOKEN Y CÓDIGO ACTUAL DE LA MÁQUINA
                        Builder(
                          builder: (context) {
                            final sessionData = controller.machineSessionCodes[machineId];
                            final currentPin = sessionData != null && sessionData['code'] != null
                                ? sessionData['code'].toString()
                                : '----';
                            final machineToken = config['token'] ?? config['machine_token'] ?? machineId;
                            final expiresAt = sessionData != null && sessionData['expires_at'] != null
                                ? sessionData['expires_at'].toString().split('T').last.split('.').first
                                : null;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.vpn_key_rounded, size: 16, color: Color(0xFF4F46E5)),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'PIN Activo / Token de Máquina',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'PIN en Pantalla:',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          Text(
                                            currentPin,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                              color: Color(0xFF1E1B4B),
                                            ),
                                          ),
                                          if (expiresAt != null)
                                            Text(
                                              'Expira a las: $expiresAt',
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                      IconButton(
                                        tooltip: 'Copiar Token',
                                        icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF4F46E5)),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: machineToken.toString()));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Token de máquina copiado al portapapeles'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Token ID: $machineToken',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 24),
                        const Text(
                          'Red y Conectividad',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: ssidController,
                          decoration: const InputDecoration(
                            labelText: 'WiFi SSID',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.wifi),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'WiFi Contraseña',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: serverController,
                          decoration: const InputDecoration(
                            labelText: 'IP Servidor / Host',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.dns),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setStateModal(() => isSaving = true);
                              final newTtl = int.tryParse(ttlController.text.trim());
                              final newSsid = ssidController.text.trim();
                              final newPass = passController.text.trim();
                              final newServer = serverController.text.trim();

                              final ok = await controller.updateMachineConfig(
                                machineId,
                                codeTtl: newTtl,
                                wifiSsid: newSsid.isNotEmpty ? newSsid : null,
                                wifiPassword: newPass.isNotEmpty ? newPass : null,
                                serverIp: newServer.isNotEmpty ? newServer : null,
                              );

                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Configuración de máquina guardada exitosamente.'
                                      : 'Error al actualizar configuración de máquina.'),
                                  backgroundColor: ok ? Colors.green : Colors.redAccent,
                                ),
                              );
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTopSellersDialog(BuildContext context, AdminDashboardController controller, String machineId) {
    final stats = controller.topSellers[machineId] ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Lo más vendido'),
        content: SizedBox(
          width: double.maxFinite,
          child: stats.isEmpty
              ? const Text('No hay ventas registradas.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: stats.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text('Slot ${stats[i]['slot']}'),
                    trailing: Text('${stats[i]['count']} ventas', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _buildAdminBannerTab(BuildContext context) {
    return const _AdminMarketingTab();
  }

  Widget _buildMainDashboard(
    BuildContext context,
    ProfileController profile,
    WalletController wallet,
    AuthSession session,
    bool linked,
    dynamic walletInfo,
  ) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // Profile & Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _DashboardAvatar(
                      base64Image: profile.profile?.avatarBase64,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.profile?.displayName ??
                                session.email.split('@').first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            session.email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (session.role == 'ADMIN')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Saldo disponible',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      linked
                          ? 'Bs. ${walletInfo!.balance.toStringAsFixed(2)}'
                          : 'No vinculado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (wallet.loading)
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
                if (wallet.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      wallet.error!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (!linked) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Activa tu billetera',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Debes vincular tu cuenta con SimuPay para realizar pagos y transferencias.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final uri = Uri.parse(
                        '${AppConfig.simupayWebUrl}/signup',
                      );
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Crear cuenta SimuPay'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (linked) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vinculado a: ${walletInfo?.email}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            'Operaciones',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Quick Actions Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _QuickActionTile(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Pagar con QR',
                color: const Color(0xFF4F46E5),
                onTap:
                    linked
                        ? () async {
                          final rawCode = (await Navigator.of(
                            context,
                          ).push<String>(
                            MaterialPageRoute(
                              builder: (_) => const QrScannerScreen(),
                            ),
                          ))?.trim();

                          if (!context.mounted ||
                              rawCode == null ||
                              rawCode.isEmpty) {
                            return;
                          }

                          debugPrint('QR Detectado: $rawCode');

                          final purchase = context.read<PurchaseController>();
                          bool success = false;
                          bool openTransfer = false;

                          // Lógica inteligente de detección de QR
                          if (rawCode.contains('/init/')) {
                            // Es un QR de Máquina (Arduino)
                            final normalizedRawCode = rawCode
                                .replaceAll('http;//', 'http://')
                                .replaceAll('https;//', 'https://');
                            final uri = Uri.tryParse(normalizedRawCode);

                            String machineId;
                            String? productId;
                            double? amount;
                            if (uri != null && uri.path.contains('/init/')) {
                              machineId = uri.pathSegments.last;
                              productId = uri.queryParameters['product_id'];
                              amount = double.tryParse(
                                uri.queryParameters['amount'] ?? '',
                              );
                            } else {
                              final split = normalizedRawCode.split('/init/');
                              final machinePart = split.last.split('?').first;
                              machineId = machinePart;
                            }
                            
                            debugPrint('Iniciando TX Máquina: $machineId');
                            success = await purchase.initMachineTransaction(
                              machineId,
                              productId: productId,
                              amount: amount,
                            );
                          } else if (rawCode.startsWith('simupay://pay')) {
                            final uri = Uri.tryParse(rawCode);
                            final hasEnrollment =
                                (uri?.queryParameters['enrollment'] ?? '')
                                    .isNotEmpty;
                            final hasRecipient =
                                (uri?.queryParameters['to'] ?? '').isNotEmpty;

                            if (hasRecipient && !hasEnrollment) {
                              openTransfer = true;
                            } else {
                              // Es un QR de pago de sesión SimuPay
                              // Formato: simupay://pay?id=...&enrollment=TX_ID
                              try {
                                final txId = uri?.queryParameters['enrollment'];
                                if (txId != null && txId.isNotEmpty) {
                                  success = await purchase.loadTransaction(
                                    txId,
                                  );
                                } else {
                                  final id = uri?.queryParameters['id'];
                                  if (id != null && id.isNotEmpty) {
                                    success = await purchase.loadTransaction(
                                      id,
                                    );
                                  } else {
                                    success = await purchase.loadTransaction(
                                      rawCode,
                                    );
                                  }
                                }
                              } catch (e) {
                                success = await purchase.loadTransaction(
                                  rawCode,
                                );
                              }
                            }
                          } else if (rawCode.startsWith('simupay://user/')) {
                            openTransfer = true;
                          } else {
                            // Es un ID de transacción de plataforma directo
                            try {
                              success = await purchase.loadTransaction(rawCode);
                            } catch (e) {
                              openTransfer = true;
                            }
                          }

                          if (!context.mounted) return;

                          if (openTransfer) {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => TransferScreen(
                                      initialQrData: rawCode,
                                    ),
                              ),
                            );
                            if (!context.mounted) return;
                            await _load();
                            return;
                          }

                          if (success && purchase.transaction != null) {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => PaymentConfirmationScreen(
                                      transactionId: purchase.transaction!.id,
                                    ),
                              ),
                            );
                            if (!context.mounted) return;
                            await _load();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  purchase.error ?? 'Error al procesar QR',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                        : null,
              ),
              _QuickActionTile(
                icon: Icons.send_to_mobile_rounded,
                label: 'Transferir',
                color: const Color(0xFF10B981),
                onTap:
                    linked
                        ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TransferScreen(),
                          ),
                        )
                        : null,
              ),
              _QuickActionTile(
                icon: Icons.history_rounded,
                label: 'Historial',
                color: const Color(0xFFF59E0B),
                onTap:
                    linked
                        ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
                        )
                        : null,
              ),
              _QuickActionTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Vincular',
                color: const Color(0xFF6366F1),
                onTap: () async {
                  final uri = Uri.parse(
                    '${AppConfig.simupayWebUrl}/login?redirect=grog://wallet/callback',
                  );
                  try {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al abrir el navegador: $e')),
                    );
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),

        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      disabled ? Colors.grey.shade100 : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: disabled ? Colors.grey : color,
                  size: 24,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: disabled ? Colors.grey : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardAvatar extends StatelessWidget {
  final String? base64Image;

  const _DashboardAvatar({required this.base64Image});

  @override
  Widget build(BuildContext context) {
    if (base64Image == null || base64Image!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 24),
      );
    }
    final bytes = _getDecodedBytes(base64Image!);
    if (bytes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 24),
      );
    }
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundImage: MemoryImage(bytes),
      ),
    );
  }
}

class _AdminMarketingTab extends StatefulWidget {
  const _AdminMarketingTab();

  @override
  State<_AdminMarketingTab> createState() => _AdminMarketingTabState();
}

class _AdminMarketingTabState extends State<_AdminMarketingTab> {
  late TextEditingController _bannerTitleCtrl;
  late TextEditingController _bannerConceptCtrl;

  final TextEditingController _pushTitleCtrl = TextEditingController();
  final TextEditingController _pushSummaryCtrl = TextEditingController();
  final TextEditingController _pushDescCtrl = TextEditingController();
  String _selectedPushType = 'info';

  bool _isSendingPush = false;
  bool _isSavingBanner = false;

  @override
  void initState() {
    super.initState();
    final admin = context.read<AdminDashboardController>();
    _bannerTitleCtrl = TextEditingController(text: admin.banner['title'] ?? '');
    _bannerConceptCtrl = TextEditingController(text: admin.banner['concept'] ?? '');
  }

  @override
  void dispose() {
    _bannerTitleCtrl.dispose();
    _bannerConceptCtrl.dispose();
    _pushTitleCtrl.dispose();
    _pushSummaryCtrl.dispose();
    _pushDescCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminDashboardController>();
    final bannerImage = controller.banner['image_base64'] ?? '';

    // Si cambió el banner desde fuera y no estamos escribiendo
    if (_bannerTitleCtrl.text != (controller.banner['title'] ?? '') && !_bannerTitleCtrl.selection.isValid) {
      _bannerTitleCtrl.text = controller.banner['title'] ?? '';
    }
    if (_bannerConceptCtrl.text != (controller.banner['concept'] ?? '') && !_bannerConceptCtrl.selection.isValid) {
      _bannerConceptCtrl.text = controller.banner['concept'] ?? '';
    }

    const primaryColor = Color(0xFF4F46E5);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Encabezado
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.campaign_rounded, color: primaryColor, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Difusión & Publicidad',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Gestiona carteles fijos y alertas a clientes',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // SECCIÓN 1: CARTEL FIJO / BANNER
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.view_carousel_rounded, size: 20, color: primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Cartel Destacado',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'En Notificaciones',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Previsualización de Imagen
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: bannerImage.isNotEmpty
                      ? Stack(
                          children: [
                            Image.memory(
                              _getDecodedBytes(bannerImage),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                  onPressed: () => controller.setBannerImage(''),
                                  tooltip: 'Quitar imagen',
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 38, color: Colors.grey.shade400),
                              const SizedBox(height: 6),
                              Text(
                                'Sin imagen seleccionada',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 12),

                // Botón Seleccionar Imagen
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 900);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        final base64Image = base64Encode(bytes);
                        controller.setBannerImage(base64Image);
                      }
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(bannerImage.isEmpty ? 'Elegir Imagen del Cartel' : 'Cambiar Imagen'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Campos
                TextField(
                  controller: _bannerTitleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Título del Cartel',
                    hintText: 'Ej. Gran Descuento de Fin de Semana',
                    labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _bannerConceptCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Concepto / Detalle de la Campaña',
                    hintText: 'Ej. 2x1 en todos los refrescos helados hasta las 20:00.',
                    labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor)),
                  ),
                ),
                const SizedBox(height: 16),

                // Guardar Cartel
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingBanner
                        ? null
                        : () async {
                            setState(() => _isSavingBanner = true);
                            final success = await controller.updateBanner(
                              _bannerTitleCtrl.text.trim(),
                              _bannerConceptCtrl.text.trim(),
                              controller.banner['image_base64'] ?? '',
                            );
                            setState(() => _isSavingBanner = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        success ? Icons.check_circle : Icons.error_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          success
                                              ? 'Cartel publicado exitosamente'
                                              : 'Error al publicar: ${controller.error ?? "error desconocido"}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          },
                    icon: _isSavingBanner
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(_isSavingBanner ? 'Guardando...' : 'Guardar y Publicar Cartel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // SECCIÓN 2: DIFUSIÓN PUSH MASIVA (EN VIVO)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.send_rounded, size: 20, color: primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Envío Masivo a Clientes',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Push en vivo',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Transmite una notificación instantánea a todas las cuentas registradas en la aplicación.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                // Selector de Tipo de Notificación Minimalista
                Row(
                  children: [
                    Expanded(
                      child: _buildTypePill('info', 'Informativo', Icons.info_outline, primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypePill('success', 'Oferta / Promo', Icons.local_offer_outlined, const Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypePill('warning', 'Alerta / Aviso', Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _pushTitleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Título de la Notificación',
                    hintText: 'Ej. ¡Nuevos refrescos disponibles!',
                    labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _pushSummaryCtrl,
                  decoration: InputDecoration(
                    labelText: 'Resumen Breve',
                    hintText: 'Texto corto visible en la previsualización push',
                    labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _pushDescCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Mensaje Completo',
                    hintText: 'Descripción detallada que leerá el usuario al abrir la alerta.',
                    labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor)),
                  ),
                ),
                const SizedBox(height: 16),

                // Botón Enviar a Todos
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSendingPush
                        ? null
                        : () async {
                            final title = _pushTitleCtrl.text.trim();
                            final summary = _pushSummaryCtrl.text.trim();
                            final desc = _pushDescCtrl.text.trim();

                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor ingresa un título')),
                              );
                              return;
                            }

                            if (desc.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Por favor ingresa el mensaje completo')),
                              );
                              return;
                            }

                            setState(() => _isSendingPush = true);
                            final success = await controller.sendBroadcast(
                              title,
                              summary.isEmpty ? title : summary,
                              desc,
                              _selectedPushType,
                            );
                            setState(() => _isSendingPush = false);

                            if (context.mounted) {
                              if (success) {
                                _pushTitleCtrl.clear();
                                _pushSummaryCtrl.clear();
                                _pushDescCtrl.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text('Notificación transmitida a todos los usuarios'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al enviar: ${controller.error ?? "error desconocido"}'),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    icon: _isSendingPush
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isSendingPush ? 'Transmitiendo a todos...' : 'Enviar a Todos Ahora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildTypePill(String type, String label, IconData icon, Color color) {
    final isSelected = _selectedPushType == type;
    return InkWell(
      onTap: () => setState(() => _selectedPushType = type),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
