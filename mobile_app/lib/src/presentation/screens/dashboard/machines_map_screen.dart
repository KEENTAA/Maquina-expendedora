import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../controllers/admin_dashboard_controller.dart';

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
       context.read<AdminDashboardController>().loadStats();
    });
  }

  Future<void> _initLocation() async {
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

    _currentPosition = await Geolocator.getCurrentPosition();
    setState(() => _isLoading = false);
  }

  double _calculateDistance(double lat, double lng) {
    if (_currentPosition == null) return 0.0;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude, 
      _currentPosition!.longitude, 
      lat, 
      lng
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
          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 50),
        )
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
            width: 100,
            height: 100,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _showMachineDetails(context, m, controller.inventories[m['id']] ?? [], distance);
              },
              child: Column(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 40),
                if (_currentPosition != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red, width: 1)
                    ),
                    child: Text(_formatDistance(distance), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  )
                ],
              ),
            ),
          )
        );
      }
    }

    LatLng initialCenter = _currentPosition != null 
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(-16.5000, -68.1193); // La Paz default

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de Máquinas')),
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
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showMachineDetails(BuildContext context, Map<String, dynamic> machine, List<dynamic> inventory, double distance) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(machine['name'] ?? 'Máquina Desconocida', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('A ${distance.toStringAsFixed(1)} km de ti', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Productos Disponibles:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: inventory.isEmpty 
                      ? const Center(child: Text('No hay productos registrados.'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: inventory.length,
                          itemBuilder: (context, index) {
                            final item = inventory[index];
                            final stock = item['stock'] ?? 0;
                            final isEnabled = item['is_enabled'] ?? true;
                            if (!isEnabled || stock == 0) return const SizedBox.shrink(); 
                            
                            final name = item['product_name'] ?? 'Producto ${item['slot']}';
                            final type = item['slot_type'] ?? 'soda';
                            final price = double.tryParse(item['price'].toString()) ?? 0.0;
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[50],
                                child: Icon(type == 'soda' ? Icons.local_drink : Icons.fastfood, color: Colors.blue),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Quedan: $stock unidades'),
                              trailing: Text('Bs. ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
  }

}
