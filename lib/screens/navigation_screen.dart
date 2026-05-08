import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/shipment.dart';

enum NavPhase { toOrigin, toDestination, arrived }

class NavigationScreen extends StatefulWidget {
  final Shipment? shipment;
  final LatLng origin;
  final LatLng destination;

  const NavigationScreen({
    super.key,
    required this.shipment,
    required this.origin,
    required this.destination,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();
  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';

  NavPhase _phase = NavPhase.toOrigin;
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  bool _awaitingLocation = true;
  String _eta = '--';
  String _distance = '--';
  String _nextInstruction = '';
  String _nextRoad = '';
  IconData _instructionIcon = Icons.straight;

  // GPS live tracking
  StreamSubscription<Position>? _positionSub;
  Timer? _rerouteTimer;

  final TextEditingController _locationController = TextEditingController();
  String _locationError = '';
  bool _pinDropMode = false;   // true = crosshair on map to drop pin

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLocationDialog());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _rerouteTimer?.cancel();
    _locationController.dispose();
    super.dispose();
  }

  // ─── Confirm dropped pin ──────────────────────────────────────────────────
  Future<void> _confirmDroppedPin() async {
    final center = _mapController.camera.center;
    setState(() {
      _pinDropMode = false;
      _currentLocation = center;
      _loadingRoute = true;
      _awaitingLocation = false;
    });
    await _fetchRoute(center, widget.origin);
    _startGpsTracking();
  }

  // ─── Geocoding ───────────────────────────────────────────────────────────
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

  // ─── Fetch route + steps ─────────────────────────────────────────────────
  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    if (!mounted) return;
    setState(() {
      _loadingRoute = true;
      _routePoints = [];
    });

    final uri = Uri.parse(
        '$_osrmBase/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true');
    final resp = await http.get(uri);
    if (!mounted) return;

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      final points =
          coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

      final durationSecs = data['routes'][0]['duration'] as num;
      final distMeters = data['routes'][0]['distance'] as num;
      final etaMin = (durationSecs / 60).round();
      final distMi = (distMeters / 1609.34).toStringAsFixed(1);

      // Parse first step for turn instruction
      final steps =
          data['routes'][0]['legs'][0]['steps'] as List? ?? [];
      if (steps.isNotEmpty) {
        final step = steps[0];
        final maneuver = step['maneuver'] as Map? ?? {};
        final type = maneuver['type'] as String? ?? 'depart';
        final modifier = maneuver['modifier'] as String? ?? '';
        final road = step['name'] as String? ?? '';
        _nextInstruction = _buildInstruction(type, modifier);
        _nextRoad = road.isNotEmpty ? road : 'Unnamed road';
        _instructionIcon = _maneuverIcon(type, modifier);
      }

      setState(() {
        _routePoints = points;
        _eta = '$etaMin min';
        _distance = '$distMi mi';
        _loadingRoute = false;
      });

      // Fit map to route
      if (points.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final bounds = LatLngBounds.fromPoints(points);
            _mapController.fitCamera(
              CameraFit.bounds(
                  bounds: bounds,
                  padding:
                      const EdgeInsets.fromLTRB(40, 130, 40, 280)),
            );
          }
        });
      }
    } else {
      setState(() => _loadingRoute = false);
    }
  }

  // ─── Turn instruction text ────────────────────────────────────────────────
  String _buildInstruction(String type, String modifier) {
    switch (type) {
      case 'depart':
        return 'Head ${modifier.isNotEmpty ? modifier : 'forward'}';
      case 'turn':
        if (modifier.contains('left')) return 'Turn left';
        if (modifier.contains('right')) return 'Turn right';
        return 'Turn';
      case 'merge':
        return 'Merge ${modifier.isNotEmpty ? modifier : ''}';
      case 'ramp':
        return 'Take the ramp';
      case 'fork':
        return 'Keep ${modifier.isNotEmpty ? modifier : 'straight'}';
      case 'end of road':
        return 'Turn at the end of road';
      case 'continue':
        return 'Continue ${modifier.isNotEmpty ? modifier : 'straight'}';
      case 'arrive':
        return 'You have arrived';
      default:
        return type.isNotEmpty ? type[0].toUpperCase() + type.substring(1) : 'Continue';
    }
  }

  IconData _maneuverIcon(String type, String modifier) {
    if (type == 'arrive') return Icons.flag;
    if (type == 'depart') return Icons.navigation;
    if (type == 'turn') {
      if (modifier.contains('sharp left') || modifier == 'left') {
        return Icons.turn_left;
      }
      if (modifier.contains('sharp right') || modifier == 'right') {
        return Icons.turn_right;
      }
      if (modifier.contains('slight left')) return Icons.turn_slight_left;
      if (modifier.contains('slight right')) return Icons.turn_slight_right;
    }
    if (type == 'fork') {
      if (modifier.contains('left')) return Icons.fork_left;
      if (modifier.contains('right')) return Icons.fork_right;
    }
    return Icons.straight;
  }

  // ─── GPS live tracking ────────────────────────────────────────────────────
  Future<void> _startGpsTracking() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) return;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30, // update every 30 m
      ),
    ).listen((pos) {
      if (!mounted) return;
      final newLoc = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = newLoc);
      // Follow user on map
      _mapController.move(newLoc, _mapController.camera.zoom);
    });

    // Re-fetch route every 60s for live rerouting
    _rerouteTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_currentLocation != null && _phase != NavPhase.arrived) {
        final target = _phase == NavPhase.toOrigin
            ? widget.origin
            : widget.destination;
        _fetchRoute(_currentLocation!, target);
      }
    });
  }

  // ─── Location dialog ──────────────────────────────────────────────────────
  void _showLocationDialog() {
    _locationController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Your Starting Location',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Enter your current city/state to calculate the route.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Houston, TX',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: _locationError.isNotEmpty
                      ? _locationError
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              // ── OR divider ──
              Row(children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ]),
              const SizedBox(height: 12),
              // ── Drop pin button ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _pinDropMode = true;
                      _awaitingLocation = false;
                    });
                  },
                  icon: const Icon(Icons.push_pin, color: Color(0xFF7C3AED)),
                  label: const Text('Drop Pin on Map',
                      style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final input = _locationController.text.trim();
                if (input.isEmpty) {
                  setDState(
                      () => _locationError = 'Please enter a location');
                  return;
                }
                setDState(() => _locationError = '');
                Navigator.pop(ctx);

                setState(() {
                  _loadingRoute = true;
                  _awaitingLocation = false;
                });

                final loc = await _geocode(input);
                if (!mounted) return;

                if (loc == null) {
                  setState(() {
                    _locationError = 'Could not find this location';
                    _awaitingLocation = true;
                    _loadingRoute = false;
                  });
                  _showLocationDialog();
                  return;
                }

                setState(() => _currentLocation = loc);
                await _fetchRoute(loc, widget.origin);
                // Start live GPS tracking in background
                _startGpsTracking();
              },
              child: const Text('Start Navigation'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shipment picked up ───────────────────────────────────────────────────
  void _onShipmentPickedUp() {
    // Move driver marker to origin (where they physically picked up)
    setState(() {
      _phase = NavPhase.toDestination;
      _currentLocation = widget.origin;
      _routePoints = [];
      _nextInstruction = '';
      _nextRoad = '';
    });
    _fetchRoute(widget.origin, widget.destination);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String get _phaseTitle {
    switch (_phase) {
      case NavPhase.toOrigin:
        return 'Navigate to Pickup';
      case NavPhase.toDestination:
        return 'Navigate to Delivery';
      case NavPhase.arrived:
        return 'Arrived!';
    }
  }

  Color get _routeColor {
    switch (_phase) {
      case NavPhase.toOrigin:
        return Colors.teal;
      case NavPhase.toDestination:
        return const Color(0xFF7C3AED);
      case NavPhase.arrived:
        return Colors.green;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Single full-screen OSM map ──────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? widget.origin,
              initialZoom: 5,
              backgroundColor: Colors.white,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flow_app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: _routeColor,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Origin (green box icon)
                  Marker(
                    point: widget.origin,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6)
                        ],
                      ),
                      child: const Icon(Icons.inventory_2,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  // Destination (red flag icon)
                  Marker(
                    point: widget.destination,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6)
                        ],
                      ),
                      child: const Icon(Icons.flag,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  // Driver (purple navigation arrow)
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 8)
                          ],
                        ),
                        child: const Icon(Icons.navigation,
                            color: Colors.white, size: 24),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Pin Drop Crosshair ──
          if (_pinDropMode)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24), // Offset for pin point
                child: Icon(Icons.push_pin, color: Color(0xFF7C3AED), size: 48, shadows: [
                  Shadow(color: Colors.white, blurRadius: 10)
                ]),
              ),
            ),
          
          if (_pinDropMode)
            const Center(
              child: Icon(Icons.add, color: Colors.black54, size: 24),
            ),

          // ── Loading overlay ─────────────────────────────────────────────
          if (_loadingRoute)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.teal),
                    SizedBox(height: 16),
                    Text('Calculating route...',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
            ),

          // ── Top header with turn instruction ────────────────────────────
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title bar
                  Container(
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
                              color: Colors.white),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_phaseTitle,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              if (!_loadingRoute && !_awaitingLocation && !_pinDropMode)
                                Text('$_distance · $_eta',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12)),
                            ],
                          ),
                        ),
                        if (!_pinDropMode)
                          GestureDetector(
                            onTap: _showLocationDialog,
                            child: const Icon(Icons.edit_location_alt,
                                color: Colors.white70),
                          ),
                      ],
                    ),
                  ),

                  // Turn instruction card (only when route is loaded)
                  if (!_awaitingLocation &&
                      !_pinDropMode &&
                      !_loadingRoute &&
                      _nextInstruction.isNotEmpty)
                    const SizedBox(height: 8),
                  if (!_awaitingLocation &&
                      !_pinDropMode &&
                      !_loadingRoute &&
                      _nextInstruction.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _routeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_instructionIcon,
                                color: _routeColor, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_nextInstruction,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.black)),
                                Text('onto $_nextRoad',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom action panel ─────────────────────────────────────────
          if (!_awaitingLocation && !_pinDropMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 20)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ETA chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                              size: 10, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Text(
                            _phase == NavPhase.arrived
                                ? 'Arrived!'
                                : 'ETA $_eta — On track',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shipment info
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.shipment?.loadId ?? 'Shipment',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black),
                        ),
                        Text(
                          widget.shipment?.rate ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: _phase == NavPhase.toOrigin
                          ? ElevatedButton.icon(
                              onPressed: _onShipmentPickedUp,
                              icon: const Icon(
                                  Icons.check_circle_outline),
                              label: const Text('Shipment Picked Up',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                              ),
                            )
                          : _phase == NavPhase.toDestination
                              ? ElevatedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.navigation),
                                  label: const Text(
                                      'En Route to Delivery',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        const Color(0xFF7C3AED),
                                    disabledForegroundColor:
                                        Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () =>
                                      Navigator.popUntil(
                                          context, (r) => r.isFirst),
                                  icon: const Icon(Icons.check),
                                  label: const Text(
                                      'Complete Delivery',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          
          // ── Pin Drop Confirm Button ──
          if (_pinDropMode)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _confirmDroppedPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: const Text('Confirm Starting Location',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
