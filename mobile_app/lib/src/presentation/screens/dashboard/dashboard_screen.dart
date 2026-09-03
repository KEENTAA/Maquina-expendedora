import 'map_picker_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../data/services/vending_api_service.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/purchase_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../../controllers/admin_dashboard_controller.dart';
import '../auth/login_screen.dart';
import '../purchase/payment_confirmation_screen.dart';
import '../purchase/qr_scanner_screen.dart';
import '../purchase/nfc_vending_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/history_screen.dart';
import '../wallet/transfer_screen.dart';
import '../../../domain/entities/auth_session.dart';
import '../../controllers/notification_controller.dart';
import '../notifications/notification_screens.dart';
import 'admin_panel_tab.dart';
import 'audit_logs_tab.dart';
import 'devops_panel_tab.dart';
import '../settings/settings_screen.dart';

// Cache to prevent jank when scrolling tabs
final Map<String, Uint8List> _base64Cache = {};

Uint8List _getDecodedBytes(String base64Str) {
  if (_base64Cache.containsKey(base64Str)) {
    return _base64Cache[base64Str]!;
  }
  final bytes = base64Decode(base64Str);
  if (_base64Cache.length > 50) _base64Cache.clear(); // simple eviction
  _base64Cache[base64Str] = bytes;
  return bytes;
}


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<Uri>? _linkSubscription;

  final VendingApiService _vendingApi = VendingApiService();
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
    final session = auth.session;
    if (session == null) return;

    await profile.load(session.email);

    if (linkWallet && linkedEmail != null) {
      await auth.linkSimupay(linkedEmail);
      await wallet.load(linkedEmail);
      return;
    }

    final targetEmail = session.simupayEmail ?? session.email;
    await wallet.load(targetEmail);
    
    if (context.mounted) {
      context.read<NotificationController>().loadNotifications(session.email);
    }
    
    // Cargar banner (a través del admin controller) para todos
    if (context.mounted) {
      context.read<AdminDashboardController>().loadStats();
    }
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
          title: const Text(
            'Grog Wallet',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
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
    if (controller.machines.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ...controller.machines.map((machine) {
          final machineId = machine['id'];
          final inventory = controller.inventories[machineId] ?? [];

          return Card(
            margin: const EdgeInsets.only(bottom: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF4F46E5),
                    child: Icon(Icons.settings_remote, color: Colors.white),
                  ),
                  title: Text(machine['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ID: $machineId | Status: ${machine['status']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.bar_chart, color: Colors.orange),
                        onPressed: () => _showTopSellersDialog(context, controller, machineId),
                      ),
                      Builder(builder: (context) {
                        bool isLightOn = controller.machineLights[machineId] ?? false;
                        return IconButton(
                          icon: Icon(
                            isLightOn ? Icons.lightbulb : Icons.lightbulb_outline,
                            color: isLightOn ? Colors.yellow : Colors.grey,
                            shadows: isLightOn ? [const BoxShadow(color: Colors.yellow, blurRadius: 10)] : null,
                          ),
                          onPressed: () => controller.toggleLights(machineId),
                        );
                      }),
                      IconButton(
                        icon: const Icon(Icons.location_on, color: Colors.blue),
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
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Distribución 4x4:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
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
                          size: 32,
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

                      return InkWell(
                        onTap: () => _showEditSlotDialog(context, controller, machineId, item),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: realEnabled ? Colors.white : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                                  ],
                                  border: Border.all(
                                    color: realEnabled ? const Color(0xFF4F46E5).withOpacity(0.3) : Colors.red.withOpacity(0.3),
                                    width: 2,
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
                                        child: Text('Bs. ${item['price']}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                      ),
                                      if (!realEnabled)
                                        const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('AGOTADO', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(fit: BoxFit.scaleDown, child: Text('${item['slot']} | Disp: $stock', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          ],
                        ),
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
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio (Bs.)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad en Stock', border: OutlineInputBorder()),
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
                if (price != null && stock != null) {
                  Navigator.pop(context);
                  await controller.updateSlotDetails(machineId, item['slot'], item['inventory_id'], price, stock, isEnabled, slotType);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
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
    final controller = context.watch<AdminDashboardController>();
    final bannerTitle = controller.banner['title'] ?? '';
    final bannerConcept = controller.banner['concept'] ?? '';
    final bannerImage = controller.banner['image_base64'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Anuncio Fijo (Cartel)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Aparece en la cima de las notificaciones siempre.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        
        TextFormField(
          initialValue: bannerTitle,
          decoration: const InputDecoration(labelText: 'Título del Anuncio', border: OutlineInputBorder()),
          onChanged: (value) => controller.banner['title'] = value,
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          initialValue: bannerConcept,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Concepto / Descripción', border: OutlineInputBorder()),
          onChanged: (value) => controller.banner['concept'] = value,
        ),
        const SizedBox(height: 24),

        if (bannerImage.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              _getDecodedBytes(bannerImage),
              height: 150, width: double.infinity, fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          )
        else
          Container(
            height: 120,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
            child: const Center(child: Text('No hay imagen seleccionada')),
          ),
        
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            final picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
            if (image != null) {
              final bytes = await image.readAsBytes();
              final base64Image = base64Encode(bytes);
              controller.banner['image_base64'] = base64Image;
              // Forzamos rebuild manual cambiando el state
              // (aunque el onChanged ya lo hace en los TextFields, aquí necesitamos update visual rápido)
              // context.read<AdminDashboardController>().notifyListeners(); no accesible directamente, pero updateBanner lo hará
            }
          },
          icon: const Icon(Icons.image),
          label: const Text('Elegir Nueva Foto'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
        ),
        
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => controller.updateBanner(
            controller.banner['title'] ?? '',
            controller.banner['concept'] ?? '',
            controller.banner['image_base64'] ?? ''
          ),
          icon: const Icon(Icons.save),
          label: const Text('Guardar y Publicar Anuncio'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
        
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        
        const Text('Lanzar Oferta / Alerta (Push en vivo)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
        const Text('Envía una notificación inmediata a todos los teléfonos.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        
        Builder(
          builder: (ctx) {
            String bTitle = '';
            String bSummary = '';
            String bDesc = '';
            return Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Título de la Oferta', border: OutlineInputBorder()),
                  onChanged: (v) => bTitle = v,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Resumen corto', border: OutlineInputBorder()),
                  onChanged: (v) => bSummary = v,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción completa', border: OutlineInputBorder()),
                  onChanged: (v) => bDesc = v,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (bTitle.isEmpty || bDesc.isEmpty) return;
                      await controller.sendBroadcast(bTitle, bSummary, bDesc, 'success');
                      if (ctx.mounted) {
                        if (controller.error != null) {
                           ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: ${controller.error}'), backgroundColor: Colors.red));
                        } else {
                           ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Notificación enviada a todos')));
                        }
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar a Todos Ahora'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            );
          }
        ),
      ],
    );
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
    final bytes = base64Decode(base64Image!);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
      ),
    );
  }
}
