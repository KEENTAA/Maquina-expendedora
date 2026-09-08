import "cart_checkout_screen.dart";
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/vending_api_service.dart';
import '../../controllers/wallet_controller.dart';



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
  static const Color primaryPurple = Color(0xFF4F46E5);
  static const Color accentPurple = Color(0xFF7C3AED);

  final VendingApiService _vendingApi = VendingApiService();
  List<dynamic> _items = [];
  bool _loading = true;
  
  // Selected slot for direct purchase or cart
  dynamic _selectedItem;

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
        _items = (inv['items'] as List<dynamic>? ?? [])
            .where((i) => (i['is_enabled'] ?? true) && ((i['stock'] ?? 0) > 0))
            .toList();
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

  Future<void> _buySelectedItemDirectly(dynamic item) async {
    final wallet = context.read<WalletController>();
    final balance = wallet.wallet?.balance ?? 0.0;
    final price = double.tryParse(item['price'].toString()) ?? 0.0;

    if (balance < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo insuficiente en la billetera.'), backgroundColor: Colors.red),
      );
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartCheckoutScreen(
          cartItems: [item],
          machineId: widget.machineId,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _checkoutCart() async {
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
       Navigator.pop(context);
    } else if (result != null && mounted) {
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Comprar vía NFC'),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.token != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 14.0),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_secondsLeft}s',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _secondsLeft < 10 ? Colors.amberAccent : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner de Billetera y Saldo (Diseño Morado)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryPurple.withValues(alpha: 0.12),
                  accentPurple.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: primaryPurple.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: primaryPurple, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Saldo disponible:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E1B4B)),
                    ),
                  ],
                ),
                Text(
                  'Bs ${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          
          // Subtítulo informativo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.touch_app_outlined, color: primaryPurple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selecciona el producto que deseas comprar en ${widget.machineId}:',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Grilla idéntica a la de Compra con Código (2 Columnas, tarjetas con slot, imagen, precio)
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: primaryPurple))
              : _items.isEmpty
                ? Center(
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
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final slot = item['slot'] ?? '';
                      final name = item['product_name'] ?? 'Producto $slot';
                      final price = double.tryParse(item['price'].toString()) ?? 0.0;
                      final isSelected = _selectedItem == item;
                      final imgBase64 = item['image_base64'];

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedItem = item;
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
                              // Badge de Slot superior
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
                              // Imagen del producto
                              Expanded(
                                child: (imgBase64 != null && imgBase64.toString().isNotEmpty)
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Image.memory(
                                          _getDecodedBytes(imgBase64),
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Icon(
                                        Icons.fastfood_outlined,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                              ),
                              // Nombre y precio
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Bs. ${price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.add_shopping_cart, size: 18, color: primaryPurple),
                                          onPressed: () {
                                            _addToCart(item);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('$name agregado a la cola'),
                                                duration: const Duration(seconds: 1),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
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
          
          // Barra inferior de Carrito múltiple (si se agregaron productos)
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -3)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Chip(
                              backgroundColor: primaryPurple.withValues(alpha: 0.1),
                              label: Text('${item['slot']}: ${item['product_name'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryPurple)),
                              deleteIconColor: primaryPurple,
                              onDeleted: () => _removeFromCart(item),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Cola: Bs ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          onPressed: _cartTotal <= balance ? _checkoutCart : null,
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Pagar Cola'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            // Botón inferior directo de compra si hay un slot seleccionado
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
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _selectedItem == null
                        ? null
                        : () => _buySelectedItemDirectly(_selectedItem),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(
                      _selectedItem == null
                          ? 'Selecciona un Slot'
                          : 'Comprar Slot ${_selectedItem['slot']} (Bs. ${_selectedItem['price']})',
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
            ),
        ],
      ),
    );
  }
}
