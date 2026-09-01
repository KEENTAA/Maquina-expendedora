import "cart_checkout_screen.dart";
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/vending_api_service.dart';
import '../../controllers/wallet_controller.dart';
import '../../controllers/purchase_controller.dart';
import '../../controllers/auth_controller.dart';
import 'payment_confirmation_screen.dart';

// Cache to prevent jank when scrolling
final Map<String, Uint8List> _base64Cache = {};

Uint8List _getDecodedBytes(String base64Str) {
  if (_base64Cache.containsKey(base64Str)) {
    return _base64Cache[base64Str]!;
  }
  final bytes = base64Decode(base64Str);
  if (_base64Cache.length > 50) _base64Cache.clear();
  _base64Cache[base64Str] = bytes;
  return bytes;
}


class NfcVendingScreen extends StatefulWidget {
  final String machineId;
  final String? token;

  const NfcVendingScreen({super.key, required this.machineId, this.token});

  @override
  State<NfcVendingScreen> createState() => _NfcVendingScreenState();
}

class _NfcVendingScreenState extends State<NfcVendingScreen> {
  final VendingApiService _vendingApi = VendingApiService();
  List<dynamic> _items = [];
  bool _loading = true;
  
  // Cart: list of items
  final List<dynamic> _cart = [];
  
  // Countdown
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _loadInventory();
    if (widget.token != null) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La sesión NFC ha caducado. Vuelve a acercar el teléfono.')),
          );
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    try {
      final inv = await _vendingApi.getInventory(widget.machineId);
      setState(() {
        _items = (inv['items'] as List<dynamic>? ?? []).where((i) => i['is_enabled'] ?? true).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _addToCart(dynamic item) {
    setState(() {
      _cart.add(item);
    });
  }

  void _removeFromCart(dynamic item) {
    setState(() {
      _cart.remove(item);
    });
  }

  double get _cartTotal {
    return _cart.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item['price'].toString()) ?? 0.0);
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartCheckoutScreen(
          cartItems: _cart,
          machineId: widget.machineId,
        ),
      ),
    );
    
    if (result == true && mounted) {
       // Compra completada exitosamente, cerramos la pantalla NFC
       Navigator.pop(context);
    } else if (result != null && mounted) {
       // Completada con errores o parcial, vaciamos el carrito
       setState(() {
         _cart.clear();
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletController>();
    final balance = wallet.wallet?.balance ?? 0.0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Comprar'),
        actions: [
          if (widget.token != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  '⏱️ ${_secondsLeft}s',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _secondsLeft < 10 ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Billetera y Saldo
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Saldo disponible:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                Text('Bs ${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),
          
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, // 4x4 requirement
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final name = item['product_name'] ?? 'P${item['slot']}';
                    final price = double.tryParse(item['price'].toString()) ?? 0.0;
                    
                    return InkWell(
                      onTap: () => _addToCart(item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (item['image_base64'] != null && item['image_base64'].toString().isNotEmpty)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.memory(
                                    _getDecodedBytes(item['image_base64']),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                            else
                              const Expanded(
                                child: Icon(Icons.fastfood, size: 32, color: Colors.orange),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            Text('Bs ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          
          // Carrito
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Chip(
                              label: Text(item['product_name'] ?? 'P${item['slot']}'),
                              onDeleted: () => _removeFromCart(item),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total: Bs ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ElevatedButton(
                          onPressed: _cartTotal <= balance ? _checkout : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Pagar Cola (Stack)'),
                        ),
                      ],
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
