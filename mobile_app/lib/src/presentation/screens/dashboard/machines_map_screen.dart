import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../controllers/admin_dashboard_controller.dart';

// Cache to prevent lag decoding base64 images repeatedly
final Map<String, Uint8List> _mapBase64Cache = {};

Uint8List? _getDecodedBytes(String? base64Str) {
  if (base64Str == null || base64Str.isEmpty) return null;
  if (_mapBase64Cache.containsKey(base64Str)) {
    return _mapBase64Cache[base64Str];
  }
  try {
    final bytes = base64Decode(base64Str);
    if (_mapBase64Cache.length > 50) _mapBase64Cache.clear();
    _mapBase64Cache[base64Str] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

class MachinesMapScreen extends StatefulWidget {
  const MachinesMapScreen({super.key});

  @override
  State<MachinesMapScreen> createState() => _MachinesMapScreenState();
}

class _MachinesMapScreenState extends State<MachinesMapScreen> {
  Position? _currentPosition;
  final MapController _mapController = MapController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminDashboardController>().loadMachinesOnly();
    });
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos != null) {
        _currentPosition = pos;
        if (mounted) {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _locateUser() async {
    await _initLocation();
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener tu ubicación actual. Revisa el GPS.')),
        );
      }
    }
  }

  double _calculateDistance(double lat, double lng) {
    if (_currentPosition == null) return 0.0;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminDashboardController>();
    final machines = controller.machines;

    List<Marker> markers = [];

    // User marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 60,
          height: 60,
          child: const Icon(Icons.person_pin_circle, color: Color(0xFF4F46E5), size: 50),
        ),
      );
    }

    // Machine markers
    for (var m in machines) {
      final double lat = m['lat'] != null ? double.tryParse(m['lat'].toString()) ?? 0 : 0;
      final double lng = m['lng'] != null ? double.tryParse(m['lng'].toString()) ?? 0 : 0;

      if (lat != 0 && lng != 0) {
        final distance = _calculateDistance(lat, lng);
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 110,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _showMachineDetails(context, m, controller.inventories[m['id']] ?? [], distance);
              },
              child: Column(
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                  if (_currentPosition != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent, width: 1),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        _formatDistance(distance),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    }

    LatLng initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(-16.5000, -68.1193); // La Paz default

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Máquinas'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.grog.vending',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        onPressed: _locateUser,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showMachineDetails(
    BuildContext context,
    Map<String, dynamic> machine,
    List<dynamic> inventory,
    double distance,
  ) {
    // Clonar y ordenar inventario por display_order y slot
    final sortedInventory = List<Map<String, dynamic>>.from(
      inventory.whereType<Map<String, dynamic>>(),
    )..sort((a, b) {
        final orderA = a['display_order'] ?? 0;
        final orderB = b['display_order'] ?? 0;
        if (orderA != orderB) {
          return (orderA as num).compareTo(orderB as num);
        }
        return (a['slot'] ?? '').toString().compareTo((b['slot'] ?? '').toString());
      });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    machine['name'] ?? 'Máquina Desconocida',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 4),
                      Text(
                        _currentPosition != null
                            ? 'A ${_formatDistance(distance)} de ti'
                            : 'Ubicación registrada',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Productos Disponibles:',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: sortedInventory.isEmpty
                        ? const Center(child: Text('No hay productos registrados.'))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: sortedInventory.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = sortedInventory[index];
                              final stock = item['stock'] ?? 0;
                              final isEnabled = item['is_enabled'] ?? true;
                              if (!isEnabled || stock == 0) return const SizedBox.shrink();

                              final name = item['product_name'] ?? 'Producto ${item['slot']}';
                              final slot = item['slot'] ?? '';
                              final type = item['slot_type'] ?? 'soda';
                              final price = double.tryParse(item['price'].toString()) ?? 0.0;
                              final imageBytes = _getDecodedBytes(item['image_base64']);

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: imageBytes != null
                                            ? Image.memory(
                                                imageBytes,
                                                fit: BoxFit.cover,
                                                gaplessPlayback: true,
                                              )
                                            : Icon(
                                                type == 'soda' ? Icons.local_drink : Icons.fastfood,
                                                color: const Color(0xFF4F46E5),
                                                size: 26,
                                              ),
                                      ),
                                    ),
                                    if (slot.toString().isNotEmpty)
                                      Positioned(
                                        right: -4,
                                        bottom: -4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4F46E5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            slot.toString(),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  'Stock: $stock unidades',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                                trailing: Text(
                                  'Bs. ${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
