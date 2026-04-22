import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic>? _machines;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMachines();
  }

  Future<void> _loadMachines() async {
    setState(() => _loading = true);
    final data = await _apiClient.machines();
    setState(() {
      _machines = data['machines'];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventarios')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _machines?.length ?? 0,
              itemBuilder: (context, index) {
                final m = _machines![index];
                return ListTile(
                  title: Text(m['location'] ?? 'Máquina ${m['id']}'),
                  onTap: () {
                    // Aquí podrías navegar a una vista de detalle de inventario
                    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                      appBar: AppBar(title: Text('Stock: ${m['id']}')),
                      body: StatefulBuilder(
                        builder: (context, setModalState) => FutureBuilder(
                          future: _apiClient.inventory(m['id']),
                          builder: (c, s) => s.hasData 
                            ? ListView(children: (s.data!['items'] as List).map((i) => ListTile(
                                title: Text(i['product_name']), 
                                subtitle: Text('Precio: Bs. ${i['price']}'),
                                trailing: Text('Stock: ${i['stock']}'),
                                onTap: () async {
                                  final controller = TextEditingController(text: i['price'].toString());
                                  final newPrice = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Actualizar Precio'),
                                      content: TextField(controller: controller, keyboardType: TextInputType.number),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Guardar'))
                                      ],
                                    )
                                  );
                                  if (newPrice != null) {
                                    await _apiClient.updateInventoryPrice(m['id'], i['slot'], double.parse(newPrice));
                                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Precio actualizado en esta máquina')));
                                    setModalState(() {}); // Refrescar lista
                                  }
                                },
                              )).toList())
                            : const Center(child: CircularProgressIndicator())
                        ),
                      ),
                    )));
                  },
                );
              },
            ),
    );
  }
}
