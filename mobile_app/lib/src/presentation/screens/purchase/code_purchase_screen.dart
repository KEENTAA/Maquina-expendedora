import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/vending_api_service.dart';
import '../../controllers/purchase_controller.dart';
import 'qr_scanner_screen.dart';
import 'payment_confirmation_screen.dart';

class CodePurchaseScreen extends StatefulWidget {
  final String defaultMachineId;

  const CodePurchaseScreen({
    super.key,
    this.defaultMachineId = 'MACHINE-001',
  });

  @override
  State<CodePurchaseScreen> createState() => _CodePurchaseScreenState();
}

class _CodePurchaseScreenState extends State<CodePurchaseScreen> {
  static const Color primaryPurple = Color(0xFF4F46E5);
  static const Color accentPurple = Color(0xFF7C3AED);

  final VendingApiService _vendingApi = VendingApiService();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isValidating = false;
  bool _isCodeVerified = false;
  String? _errorMessage;

  List<dynamic> _inventory = [];
  bool _loadingInventory = false;
  String? _selectedSlot;
  bool _isGeneratingQr = false;

  final Map<String, Uint8List> _imageCache = {};

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Uint8List? _decodeBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    if (_imageCache.containsKey(base64Str)) {
      return _imageCache[base64Str];
    }
    try {
      final bytes = base64Decode(base64Str);
      _imageCache[base64Str] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < 5) {
      setState(() => _errorMessage = 'El código debe tener 5 dígitos');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final res = await _vendingApi.verifyMachineCode(code, machineId: widget.defaultMachineId);
      if (res['valid'] == true) {
        setState(() {
          _isCodeVerified = true;
          _isValidating = false;
        });
        await _loadInventory();
      } else {
        setState(() {
          _isValidating = false;
          _errorMessage = res['detail'] ?? 'Código incorrecto';
        });
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _loadInventory() async {
    setState(() => _loadingInventory = true);
    try {
      final res = await _vendingApi.getInventory(widget.defaultMachineId);
      final items = (res['items'] as List<dynamic>? ?? [])
          .where((i) => i['is_enabled'] == true && (i['stock'] ?? 0) > 0)
          .toList();
      setState(() {
        _inventory = items;
        _loadingInventory = false;
      });
    } catch (e) {
      setState(() {
        _loadingInventory = false;
        _errorMessage = 'Error al cargar inventario: $e';
      });
    }
  }

  Future<void> _onGenerateQrAndScan() async {
    if (_selectedSlot == null) return;
    setState(() => _isGeneratingQr = true);

    try {
      // 1. Notificar a la máquina por backend qué slot se seleccionó
      await _vendingApi.selectSlot(widget.defaultMachineId, _selectedSlot!);

      if (!mounted) return;
      setState(() => _isGeneratingQr = false);

      // 2. Abrir inmediatamente la pantalla de escaneo QR para leer la pantalla de la máquina
      final rawCode = (await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const QrScannerScreen(),
        ),
      ))?.trim();

      if (!mounted || rawCode == null || rawCode.isEmpty) return;

      // 3. Procesar el QR leído
      final purchase = context.read<PurchaseController>();
      bool success = false;

      if (rawCode.contains('/init/')) {
        final normalized = rawCode.replaceAll('http;//', 'http://').replaceAll('https;//', 'https://');
        final uri = Uri.tryParse(normalized);
        String mId = widget.defaultMachineId;
        String? pId;
        double? amount;

        if (uri != null && uri.path.contains('/init/')) {
          mId = uri.pathSegments.last;
          pId = uri.queryParameters['product_id'];
          amount = double.tryParse(uri.queryParameters['amount'] ?? '');
        }

        success = await purchase.initMachineTransaction(
          mId,
          productId: pId ?? _selectedSlot,
          amount: amount,
          paymentMethod: 'CODE',
        );
      } else if (rawCode.startsWith('simupay://pay')) {
        final uri = Uri.tryParse(rawCode);
        final txId = uri?.queryParameters['enrollment'] ?? uri?.queryParameters['id'] ?? rawCode;
        success = await purchase.loadTransaction(txId);
      } else {
        success = await purchase.loadTransaction(rawCode);
      }

      if (!mounted) return;

      if (success && purchase.transaction != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentConfirmationScreen(
              transactionId: purchase.transaction!.id,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(purchase.error ?? 'Error al procesar QR escaneado'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingQr = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprar con Código'),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: !_isCodeVerified ? _buildCodeInputView() : _buildCatalogView(),
      ),
    );
  }

  Widget _buildCodeInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryPurple.withValues(alpha: 0.15),
                  accentPurple.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.dialpad_rounded,
              size: 72,
              color: primaryPurple,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ingresa el Código de la Máquina',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Mira la pantalla de la máquina expendedora y escribe el código de 5 dígitos que aparece en la parte superior.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 5,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              letterSpacing: 14,
              fontWeight: FontWeight.bold,
              color: primaryPurple,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '•••••',
              hintStyle: TextStyle(
                letterSpacing: 14,
                color: Colors.grey[400],
              ),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryPurple, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryPurple, width: 2.5),
              ),
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isValidating ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: _isValidating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Conectar a Máquina',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogView() {
    if (_loadingInventory) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryPurple),
            SizedBox(height: 16),
            Text('Cargando productos de la máquina...'),
          ],
        ),
      );
    }

    if (_inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No hay productos disponibles en esta máquina.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInventory,
              style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: primaryPurple.withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conectado a ${widget.defaultMachineId}. Elige un producto:',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isCodeVerified = false;
                    _codeController.clear();
                    _selectedSlot = null;
                  });
                },
                child: const Text('Cambiar', style: TextStyle(fontSize: 12, color: primaryPurple, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemCount: _inventory.length,
            itemBuilder: (context, index) {
              final item = _inventory[index];
              final slot = item['slot'] ?? '';
              final name = item['product_name'] ?? 'Producto';
              final price = item['price'] ?? 0.0;
              final isSelected = _selectedSlot == slot;
              final imgBytes = _decodeBase64(item['image_base64']);

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedSlot = slot;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? primaryPurple : Colors.grey.shade200,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? primaryPurple.withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: isSelected ? 10 : 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge Slot
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryPurple : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                slot,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: primaryPurple, size: 20),
                          ],
                        ),
                      ),
                      // Imagen
                      Expanded(
                        child: imgBytes != null
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Image.memory(
                                  imgBytes,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Icon(
                                Icons.fastfood_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                      ),
                      // Info
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bs. ${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Botón inferior "Generar QR"
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, -3),
                blurRadius: 8,
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_selectedSlot == null || _isGeneratingQr)
                  ? null
                  : _onGenerateQrAndScan,
              icon: _isGeneratingQr
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_2),
              label: Text(
                _selectedSlot == null
                    ? 'Selecciona un Slot'
                    : 'Generar QR para Slot $_selectedSlot',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
