import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _fingerprintEnabled = false;
  bool _nfcEnabled = false;
  bool _nfcAvailable = false;
  bool _fingerprintAvailable = false;
  bool _loading = true;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Check hardware availability
    bool fingerAvailable = false;
    try {
      fingerAvailable = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {}

    bool nfcAvailable = false;
    try {
      nfcAvailable = await NfcManager.instance.isAvailable();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _fingerprintAvailable = fingerAvailable;
        _nfcAvailable = nfcAvailable;
        _fingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;
        _nfcEnabled = prefs.getBool('nfc_enabled') ?? false;
        _loading = false;
      });
    }
  }

  Future<void> _promptSavePassword(String email) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.fingerprint, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Text('Vincular contraseña', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresa tu contraseña actual ($email) para guardarla de forma segura y permitir el inicio de sesión automático con tu huella.',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Omitir por ahora'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (passwordCtrl.text.trim().isNotEmpty) {
                      Navigator.of(ctx).pop(true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && passwordCtrl.text.trim().isNotEmpty) {
      await _secureStorage.write(key: 'saved_email', value: email);
      await _secureStorage.write(key: 'saved_password', value: passwordCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña vinculada exitosamente a tu huella dactilar.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleFingerprint(bool value) async {
    if (value) {
      // Verify fingerprint before enabling
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verifica tu identidad para habilitar el acceso con huella',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (!authenticated) return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de autenticación: $e'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Check and prompt for password if not stored yet
      if (mounted) {
        final auth = context.read<AuthController>();
        final email = auth.session?.email;
        if (email != null) {
          final savedPass = await _secureStorage.read(key: 'saved_password');
          final savedEmail = await _secureStorage.read(key: 'saved_email');
          if (savedPass == null || savedEmail != email) {
            await _promptSavePassword(email);
          }
        }
      }
    } else {
      // When disabling, clear saved credentials
      await _secureStorage.delete(key: 'saved_email');
      await _secureStorage.delete(key: 'saved_password');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fingerprint_enabled', value);
    if (mounted) {
      setState(() => _fingerprintEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Huella dactilar habilitada' : 'Huella dactilar deshabilitada'),
          backgroundColor: value ? Colors.green : Colors.grey,
        ),
      );
    }
  }

  Future<void> _toggleNfc(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nfc_enabled', value);
    if (mounted) {
      setState(() => _nfcEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'NFC habilitado – Acerca tu celular a la máquina' : 'NFC deshabilitado'),
          backgroundColor: value ? Colors.green : Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -- SECCIÓN SEGURIDAD --
                const Text(
                  'Seguridad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.fingerprint,
                          size: 32,
                          color: _fingerprintAvailable ? const Color(0xFF4F46E5) : Colors.grey,
                        ),
                        title: const Text('Inicio de sesión con huella', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _fingerprintAvailable
                              ? 'Usa tu huella dactilar para acceder a tu cuenta'
                              : 'Tu dispositivo no tiene sensor de huella dactilar',
                        ),
                        trailing: Switch(
                          value: _fingerprintEnabled,
                          onChanged: _fingerprintAvailable ? _toggleFingerprint : null,
                          activeColor: const Color(0xFF4F46E5),
                        ),
                      ),
                      if (_fingerprintEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Inicia sesión una vez con tu contraseña para vincular tu huella.',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // -- SECCIÓN NFC --
                const Text(
                  'Conexión con máquinas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.nfc,
                          size: 32,
                          color: _nfcAvailable ? const Color(0xFF4F46E5) : Colors.grey,
                        ),
                        title: const Text('Detección NFC', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _nfcAvailable
                              ? 'Acerca tu celular al PN532 de la máquina para ver productos'
                              : 'Tu dispositivo no tiene NFC o está desactivado en ajustes del sistema',
                        ),
                        trailing: Switch(
                          value: _nfcEnabled,
                          onChanged: _nfcAvailable ? _toggleNfc : null,
                          activeColor: const Color(0xFF4F46E5),
                        ),
                      ),
                      if (_nfcEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'NFC activo. Al acercar tu celular a una máquina se mostrarán los productos disponibles.',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_nfcAvailable)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Activa el NFC en los ajustes de tu celular para usar esta función.',
                                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // -- INFO --
                Card(
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Los permisos de NFC y huella dactilar se controlan desde aquí. '
                            'Para habilitar el NFC del sistema, ve a los Ajustes de tu teléfono.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
