import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/product_transaction.dart';
import 'purchase_result_screen.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/purchase_controller.dart';
import '../../controllers/wallet_controller.dart';

class CartCheckoutScreen extends StatefulWidget {
  final List<dynamic> cartItems;
  final String machineId;

  const CartCheckoutScreen({super.key, required this.cartItems, required this.machineId});

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  bool _isProcessing = false;
  int _currentIndex = 0;
  List<String> _successLog = [];
  List<String> _errorLog = [];
  List<ProductTransaction> _finalTransactions = [];

  double get _totalAmount {
    return widget.cartItems.fold(0.0, (sum, item) {
      final price = double.tryParse(item['price'].toString()) ?? 0.0;
      return sum + price;
    });
  }

  Future<void> _processCart() async {
    final wallet = context.read<WalletController>();
    final balance = wallet.wallet?.balance ?? 0.0;
    
    if (balance < _totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo insuficiente en la billetera.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentIndex = 0;
      _successLog = [];
      _errorLog = [];
      _finalTransactions = [];
    });

    final purchase = context.read<PurchaseController>();
    final auth = context.read<AuthController>();
    final session = auth.session;
    final payerEmail = session?.simupayEmail ?? session?.email ?? '';

    for (int i = 0; i < widget.cartItems.length; i++) {
      setState(() => _currentIndex = i);
      final item = widget.cartItems[i];
      final price = double.tryParse(item['price'].toString()) ?? 0.0;
      final slot = item['slot'];
      final productId = item['product_id'] ?? slot;
      final name = item['product_name'] ?? 'P$slot';

      try {
        final success = await purchase.initMachineTransaction(
          widget.machineId,
          productId: productId,
          amount: price,
        );

        if (success && purchase.transaction != null) {
          final confirmed = await purchase.confirmAndPay(payerEmail: payerEmail);
          if (confirmed && purchase.transaction != null) {
            _finalTransactions.add(purchase.transaction!);
            final state = purchase.transaction!.state.toString();
            if (state.contains('completed')) {
              _successLog.add('$name (Slot $slot) despachado.');
            } else if (state.contains('refunded')) {
              _errorLog.add('$name (Slot $slot) atascado. Reembolsado.');
            } else if (state.contains('failed')) {
              _errorLog.add('$name (Slot $slot) falló en máquina.');
            } else {
              _successLog.add('$name (Slot $slot) en proceso (IoT)...');
            }
          } else {
            _errorLog.add('Error al cobrar $name: ${purchase.error}');
          }
        } else {
          _errorLog.add('No se pudo iniciar $name: ${purchase.error}');
        }
      } catch (e) {
        _errorLog.add('Fallo en $name: $e');
      }
      
      // Pequeña pausa entre productos para no saturar
      await Future.delayed(const Duration(seconds: 1));
    }

    setState(() {
      _isProcessing = false;
      _currentIndex = widget.cartItems.length; // Finalizado
    });
    
    // Refresh wallet balance
    wallet.load(payerEmail);
    
    if (widget.cartItems.length == 1 && _finalTransactions.isNotEmpty) {
      if (mounted) {
         Navigator.of(context).pushReplacement(
           MaterialPageRoute(builder: (_) => PurchaseResultScreen(transaction: _finalTransactions.first))
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Factura de Compra')),
      body: _isProcessing || _currentIndex == widget.cartItems.length 
          ? _buildProgressView() 
          : _buildInvoiceView(),
    );
  }

  Widget _buildInvoiceView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumen de tu pedido',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView.separated(
                  itemCount: widget.cartItems.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = widget.cartItems[index];
                    final name = item['product_name'] ?? 'Producto ${item['slot']}';
                    final price = double.tryParse(item['price'].toString()) ?? 0.0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${index + 1}. $name (${item['slot']})', style: const TextStyle(fontSize: 16)),
                        Text('Bs. ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a Pagar:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(
                    'Bs. ${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _processCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmar y Pagar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProgressView() {
    bool isFinished = _currentIndex == widget.cartItems.length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isFinished) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 32),
            Text(
              'Procesando producto ${_currentIndex + 1} de ${widget.cartItems.length}...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Por favor, no cierres la aplicación',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ] else ...[
            Icon(
              _errorLog.isEmpty ? Icons.check_circle : Icons.warning,
              size: 80,
              color: _errorLog.isEmpty ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              _errorLog.isEmpty ? '¡Compra Completada!' : 'Compra finalizada con algunos errores',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_successLog.isNotEmpty) ...[
              const Text('Entregados:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._successLog.map((s) => Text('✅ $s')),
              const SizedBox(height: 12),
            ],
            if (_errorLog.isNotEmpty) ...[
              const Text('Errores:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ..._errorLog.map((e) => Text('❌ $e', style: const TextStyle(color: Colors.red))),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_successLog.length == widget.cartItems.length);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Volver al inicio', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}
