import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/audit_controller.dart';
import '../../../domain/entities/audit_log.dart';

class AuditLogsTab extends StatefulWidget {
  const AuditLogsTab({super.key});

  @override
  State<AuditLogsTab> createState() => _AuditLogsTabState();
}

class _AuditLogsTabState extends State<AuditLogsTab> {
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuditController>().fetchLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuditController>();

    return Column(
      children: [
        // Filtros
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text('Categoría: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedCategory,
                items: const [
                  DropdownMenuItem(value: '', child: Text('TODOS')),
                  DropdownMenuItem(value: 'SECURITY', child: Text('SEGURIDAD')),
                  DropdownMenuItem(value: 'APPLICATION', child: Text('APLICACIÓN')),
                  DropdownMenuItem(value: 'HARDWARE', child: Text('HARDWARE')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                    context.read<AuditController>().fetchLogs(category: val);
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<AuditController>().fetchLogs(category: _selectedCategory),
              )
            ],
          ),
        ),

        // Lista
        Expanded(
          child: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : controller.error != null
                  ? Center(child: Text(controller.error!, style: const TextStyle(color: Colors.red)))
                  : ListView.builder(
                      itemCount: controller.logs.length,
                      itemBuilder: (context, index) {
                        final log = controller.logs[index];
                        return _buildLogCard(log);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildLogCard(AuditLog log) {
    Color cardColor;
    IconData iconData;

    switch (log.category) {
      case 'SECURITY':
        cardColor = Colors.red.shade50;
        iconData = Icons.security;
        break;
      case 'HARDWARE':
        cardColor = Colors.orange.shade50;
        iconData = Icons.memory;
        break;
      case 'APPLICATION':
      default:
        cardColor = Colors.blue.shade50;
        iconData = Icons.apps;
        break;
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final timeStr = dateFormat.format(log.timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cardColor,
      child: ExpansionTile(
        leading: Icon(iconData, color: cardColor == Colors.red.shade50 ? Colors.red : (cardColor == Colors.orange.shade50 ? Colors.orange : Colors.blue)),
        title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$timeStr | ${log.actorId ?? 'Sistema'}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                'Máquina: ${log.machineId ?? 'N/A'}\\n'
                'Detalles:\\n${log.details?.toString() ?? 'Sin detalles adicionales'}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }
}
