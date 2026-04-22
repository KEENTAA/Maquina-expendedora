import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/entities/auth_session.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/wallet_controller.dart';
import '../purchase/qr_scanner_screen.dart';

class TransferScreen extends StatefulWidget {
  final String? initialQrData;

  const TransferScreen({super.key, this.initialQrData});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _toCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  String? _qrData;

  bool get _isQrMode => _qrData != null && _qrData!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialQrData != null && widget.initialQrData!.isNotEmpty) {
      _applyQr(widget.initialQrData!);
    }
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthSession session) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
      return;
    }
    setState(() => _sending = true);
    final wallet = context.read<WalletController>();
    final payerEmail = session.simupayEmail ?? session.email;
    final ok =
        _isQrMode
            ? await wallet.payQr(
              from: payerEmail,
              qrData: _qrData!,
              amount: amount,
            )
            : await wallet.transfer(
              from: payerEmail,
              to: _toCtrl.text.trim(),
              amount: amount,
            );
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Transferencia realizada'
              : (wallet.error ?? 'No se pudo transferir'),
        ),
        backgroundColor: ok ? Colors.green : Colors.redAccent,
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _scanQr() async {
    final rawCode = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (!mounted || rawCode == null || rawCode.isEmpty) return;
    _applyQr(rawCode);
  }

  void _applyQr(String rawCode) {
    _qrData = rawCode.trim();
    if (_qrData == null || _qrData!.isEmpty) return;

    if (_qrData!.startsWith('simupay://pay')) {
      final uri = Uri.tryParse(_qrData!);
      final amountParam = uri?.queryParameters['amount'];
      if (amountParam != null && amountParam.isNotEmpty) {
        final parsed = double.tryParse(amountParam);
        if (parsed != null && parsed > 0) {
          _amountCtrl.text = parsed.toStringAsFixed(2);
        }
      }
      final toParam = uri?.queryParameters['to'];
      if (toParam != null && toParam.isNotEmpty) {
        _toCtrl.text = 'QR destino: $toParam';
      }
    } else if (_qrData!.startsWith('simupay://user/')) {
      _toCtrl.text = 'QR destino detectado';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session!;
    return Scaffold(
      appBar: AppBar(title: const Text('Transferir dinero')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _toCtrl,
                decoration: const InputDecoration(
                  labelText: 'Destino (correo o wallet_id)',
                ),
                enabled: !_isQrMode,
                validator:
                    (v) =>
                        (!_isQrMode && (v == null || v.trim().isEmpty))
                            ? 'Campo obligatorio'
                            : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : _scanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(
                    _isQrMode
                        ? 'QR cargado (tocar para re-escanear)'
                        : 'Escanear QR de transferencia',
                  ),
                ),
              ),
              if (_isQrMode)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _qrData!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Monto'),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Campo obligatorio'
                            : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sending ? null : () => _submit(session),
                  child: Text(_sending ? 'Enviando...' : 'Transferir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
