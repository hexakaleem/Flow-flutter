import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/shipment.dart';

class ShipmentDetailScreen extends StatefulWidget {
  final Shipment? shipment;
  const ShipmentDetailScreen({super.key, this.shipment});

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  bool _loadingRoute = true;
  String _routeDistance = '--';
  String _routeTime = '--';

  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';

  @override
  void initState() {
    super.initState();
    _buildRoute();
  }

  Future<LatLng?> _geocode(String place) async {
    final uri = Uri.parse(
        '$_nominatimBase/search?q=${Uri.encodeQueryComponent(place)}&format=json&limit=1');
    final resp = await http.get(uri, headers: {'User-Agent': 'FlowApp/1.0'});
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body) as List;
      if (data.isNotEmpty) {
        return LatLng(
          double.parse(data[0]['lat']),
          double.parse(data[0]['lon']),
        );
      }
    }
    return null;
  }

  Future<void> _buildRoute() async {
    final origin = widget.shipment?.origin ?? 'Dallas, TX';
    final destination = widget.shipment?.destination ?? 'Atlanta, GA';

    final o = await _geocode(origin);
    final d = await _geocode(destination);

    if (o == null || d == null) {
      setState(() => _loadingRoute = false);
      return;
    }

    _originLatLng = o;
    _destinationLatLng = d;

    // Fetch OSRM route
    final uri = Uri.parse(
        '$_osrmBase/${o.longitude},${o.latitude};${d.longitude},${d.latitude}?overview=full&geometries=geojson');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      _routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

      // Real distance and duration from OSRM
      final distMeters = data['routes'][0]['distance'] as num;
      final durationSecs = data['routes'][0]['duration'] as num;
      final distMi = (distMeters / 1609.34).toStringAsFixed(0);
      final hours = (durationSecs / 3600).floor();
      final mins = ((durationSecs % 3600) / 60).round();
      _routeDistance = '$distMi mi';
      _routeTime = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    }

    setState(() => _loadingRoute = false);

    // Fit map to bounds
    if (_routePoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    }
  }

  void _openNavigation() {
    if (_originLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route not ready yet, please wait...')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/navigation',
      arguments: {
        'shipment': widget.shipment,
        'origin': _originLatLng,
        'destination': _destinationLatLng,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shipment;
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen OSM map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(33.0, -89.0),
              initialZoom: 5.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flow_app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4,
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              if (_originLatLng != null && _destinationLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _originLatLng!,
                      width: 40,
                      height: 40,
                      child: const _MarkerIcon(color: Colors.green, icon: Icons.circle),
                    ),
                    Marker(
                      point: _destinationLatLng!,
                      width: 40,
                      height: 40,
                      child: const _MarkerIcon(color: Colors.red, icon: Icons.location_pin),
                    ),
                  ],
                ),
            ],
          ),

          // Loading indicator
          if (_loadingRoute)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
            ),

          // Top header pill
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1128),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Text(
                        'Current Shipment',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openNavigation,
                      icon: const Icon(Icons.navigation, size: 14),
                      label: const Text('Navigate', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Draggable bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.25,
            maxChildSize: 0.65,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Shipment ID and rate
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: Colors.brown),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s?.loadId ?? '549SD00X87',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                                Text('${s?.commodity ?? 'Freight'} · Reefer',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(s?.rate ?? '\$2,800',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
                            const Text('↑ \$3.50 / mi',
                                style: TextStyle(color: Colors.green, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Origin
                    _buildRouteStep(
                      location: s?.origin ?? 'Dallas, TX',
                      date: s?.originDate ?? 'April 1, 2026 · 08:00',
                      status: 'Picked up',
                      isFirst: true,
                      isPickedUp: true,
                    ),
                    // Destination
                    _buildRouteStep(
                      location: s?.destination ?? 'Atlanta, GA',
                      date: s?.destinationDate ?? 'April 2, 2026 · 14:30',
                      status: 'En route',
                      isFirst: false,
                      isPickedUp: false,
                    ),
                    const SizedBox(height: 20),

                    // Stats — real values from OSRM
                    Row(
                      children: [
                        _buildStatItem(Icons.location_on_outlined, 'Distance', _routeDistance),
                        const SizedBox(width: 12),
                        _buildStatItem(Icons.timer_outlined, 'Time left', _routeTime),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatItem(Icons.shopping_cart_outlined, 'Weight', s?.weight ?? '38,500 lbs'),
                        const SizedBox(width: 12),
                        _buildStatItem(Icons.thermostat_outlined, 'Temp', '-4°C'),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Open Navigation button
                    Row(
                      children: [
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.phone_outlined, color: Colors.black),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openNavigation,
                            icon: const Icon(Icons.navigation),
                            label: const Text('Open Navigation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.description_outlined, color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStep({
    required String location,
    required String date,
    required String status,
    required bool isFirst,
    required bool isPickedUp,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(Icons.circle,
                  size: 12, color: isPickedUp ? Colors.black : Colors.orange),
              if (isFirst)
                Container(width: 2, height: 40, color: Colors.grey.shade200),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPickedUp ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(status,
                      style: TextStyle(
                        color: isPickedUp ? Colors.blue : Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.red.shade300),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _MarkerIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
