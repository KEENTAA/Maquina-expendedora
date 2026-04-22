import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class IoTControlScreen extends StatefulWidget {
  const IoTControlScreen({super.key});

  @override
  State<IoTControlScreen> createState() => _IoTControlScreenState();
}

class _IoTControlScreenState extends State<IoTControlScreen> {
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
    try {
      final data = await _apiClient.iotMachines();
      setState(() {
        _machines = data['machines'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendCommand(String machineId, String cmd) async {
    try {
      await _apiClient.iotCommand(machineId, cmd);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Comando $cmd enviado')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control IoT')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _machines?.length ?? 0,
              itemBuilder: (context, index) {
                final m = _machines![index];
                return ListTile(
                  title: Text('Máquina: ${m['id']}'),
                  subtitle: Text('Estado: ${m['status']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _sendCommand(m['id'], 'reboot'),
                  ),
                );
              },
            ),
    );
  }
}
