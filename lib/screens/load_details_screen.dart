import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/load.dart';
import '../services/auth_service.dart';
import '../services/load_service.dart';
import '../services/shipment_service.dart';
import '../services/notification_service.dart';
import '../widgets/custom_bottom_nav.dart';

class LoadDetailsScreen extends StatefulWidget {
  final Load load;

  const LoadDetailsScreen({
    super.key,
    required this.load,
  });

  @override
  State<LoadDetailsScreen> createState() => _LoadDetailsScreenState();
}

class _LoadDetailsScreenState extends State<LoadDetailsScreen> {
  late Load _load;
  bool _isLoading = false;
  final AuthService _auth = AuthService();
  final LoadService _loadService = LoadService();
  final ShipmentService _shipmentService = ShipmentService();
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  bool _mapLoading = true;

  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';

  @override
  void initState() {
    super.initState();
    _load = widget.load;
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
    final originStr = '${_load.origin}, ${_load.originState}';
    final destStr = '${_load.destination}, ${_load.destinationState}';
    LatLng? o = await _geocode(originStr);
    LatLng? d = await _geocode(destStr);
    o ??= await _geocode(_load.origin);
    d ??= await _geocode(_load.destination);
    if (o == null || d == null) {
      setState(() => _mapLoading = false);
      return;
    }
    _originLatLng = o;
    _destinationLatLng = d;
    final uri = Uri.parse(
        '$_osrmBase/${o.longitude},${o.latitude};${d.longitude},${d.latitude}?overview=full&geometries=geojson');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      _routePoints =
          coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
    }
    setState(() => _mapLoading = false);
    if (_routePoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bounds = LatLngBounds.fromPoints(_routePoints);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
        );
      });
    }
  }

  Future<void> _bookLoad() async {
    final user = _auth.currentUser;
    final hasVehicleProfile =
        user != null && _auth.hasVehicleProfile(user.id);

    if (!hasVehicleProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Complete vehicle registration before booking this load.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bookSuccess = await _loadService.bookLoad(_load.id);
      if (bookSuccess) {
        final addSuccess = await _shipmentService.addShipment(
          loadId: _load.loadNumber,
          commodity: _load.commodity,
          origin: _load.origin,
          destination: _load.destination,
          originDate: _load.originDate,
          destinationDate: _load.destinationDate,
          weight: _load.weight,
          rate: _load.rate,
        );

        if (addSuccess) {
          // Fire notification
          await NotificationService().notifyLoadBooked(_load.loadNumber);

          setState(() {
            _isLoading = false;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Load booked successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          Navigator.pop(context);
          Navigator.pushNamedAndRemoveUntil(
              context, '/home', (route) => false);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking load: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            height: 350,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFCE9FFC),
                  Colors.white,
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120), // For bottom nav
              child: Column(
                children: [
                  // Top Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1128),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Text(
                              'Load details',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Live OSM Map
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SizedBox(
                        height: 200,
                        child: _mapLoading
                            ? Container(
                                color: Colors.grey.shade100,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF7C3AED)),
                                ),
                              )
                            : FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _originLatLng ??
                                      const LatLng(33.0, -89.0),
                                  initialZoom: 6,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag
                                        .none, // disable scroll to keep UX clean
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.example.flow_app',
                                  ),
                                  if (_routePoints.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: _routePoints,
                                          strokeWidth: 3.5,
                                          color: const Color(0xFF7C3AED),
                                        ),
                                      ],
                                    ),
                                  if (_originLatLng != null &&
                                      _destinationLatLng != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: _originLatLng!,
                                          width: 30,
                                          height: 30,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 2),
                                            ),
                                            child: const Icon(Icons.circle,
                                                color: Colors.white, size: 12),
                                          ),
                                        ),
                                        Marker(
                                          point: _destinationLatLng!,
                                          width: 30,
                                          height: 30,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 2),
                                            ),
                                            child: const Icon(
                                                Icons.location_pin,
                                                color: Colors.white,
                                                size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Timeline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildTimelineStep(
                          isFirst: true,
                          pillText: 'Pick up',
                          pillColor: Colors.purpleAccent,
                          companyName: 'Fresh Food Inc.',
                          rating: '3.5',
                          address: '${_load.origin}, ${_load.originState}',
                          date: '${_load.originDate} • ${_load.originTime}',
                        ),
                        _buildTimelineStep(
                          isFirst: false,
                          pillText: 'Delivery',
                          pillColor: Colors.teal,
                          companyName: 'Smart Food Inc.',
                          rating: '4.5',
                          address:
                              '${_load.destination}, ${_load.destinationState}',
                          date:
                              '${_load.destinationDate} • ${_load.destinationTime}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Details Section
                  _buildSectionTitle('Details'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildInfoItem(
                                Icons.qr_code_scanner, 'ID', _load.loadNumber)),
                        Expanded(
                            child: _buildInfoItem(Icons.inventory_2_outlined,
                                'Commodity', _load.commodity)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildInfoItem(Icons.view_in_ar_outlined,
                                'Load', '4 Pallets')),
                        Expanded(
                            child: _buildInfoItem(Icons.local_shipping_outlined,
                                'Weight', _load.weight)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Additional Info Section
                  _buildSectionTitle('Additional info'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildInfoItem(Icons.route_outlined,
                                'Distance', _load.distance)),
                        Expanded(
                            child: _buildInfoItem(
                                Icons.timer_outlined, 'Time', '25 mins')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildInfoItem(
                                Icons.monetization_on_outlined,
                                'Rate per mile',
                                _load.rateUnit)),
                        Expanded(
                            child: _buildInfoItem(Icons.payments_outlined,
                                'Estimated earns', _load.rate)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Book Load Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _bookLoad,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: Colors.teal.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Book Load',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2, // load details usually opened from load board
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/home');
          if (index == 1) Navigator.pushNamed(context, '/order_history');
          if (index == 2) Navigator.pop(context);
          if (index == 3) Navigator.pushNamed(context, '/stats');
        },
      ),
    );
  }

  Widget _buildTimelineStep({
    required bool isFirst,
    required String pillText,
    required Color pillColor,
    required String companyName,
    required String rating,
    required String address,
    required String date,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 4),
              ),
            ),
            if (isFirst)
              Container(
                width: 2,
                height: 70,
                color: Colors.grey.shade400,
              ),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pillText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    companyName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, color: Colors.yellow, size: 14),
                  Text(
                    rating,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              Text(
                date,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold),
              ),
              if (isFirst) const SizedBox(height: 20),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.black),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
