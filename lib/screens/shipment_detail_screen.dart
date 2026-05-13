import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/shipment.dart';
import '../services/shipment_service.dart';
import '../services/notification_service.dart';

enum NavPhase { toOrigin, toDestination, arrived }

class _NavSession {
  String shipmentId = '';
  bool isActive = false;
  NavPhase phase = NavPhase.toOrigin;
  LatLng? currentLocation;
  LatLng? originLatLng;
  LatLng? destinationLatLng;
  List<LatLng> routePoints = [];
  String eta = '--';
  String distance = '--';
  String nextInstruction = '';
  String nextRoad = '';
  IconData instructionIcon = Icons.straight;

  void clear() {
    shipmentId = '';
    isActive = false;
    phase = NavPhase.toOrigin;
    currentLocation = null;
    originLatLng = null;
    destinationLatLng = null;
    routePoints = [];
    eta = '--';
    distance = '--';
    nextInstruction = '';
    nextRoad = '';
    instructionIcon = Icons.straight;
  }
}

class ShipmentDetailScreen extends StatefulWidget {
  final Shipment? shipment;
  const ShipmentDetailScreen({super.key, this.shipment});

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  static final _NavSession _session = _NavSession();

  final MapController _mapController = MapController();
  final ShipmentService _shipmentService = ShipmentService();
  final NotificationService _notifService = NotificationService();

  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';

  List<LatLng> _routePoints = [];
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  LatLng? _currentLocation;
  bool _loadingRoute = true;
  bool _isNavigating = false;
  String _nextInstruction = '';
  String _nextRoad = '';
  IconData _instructionIcon = Icons.straight;
  String _eta = '--';
  String _distance = '--';

  NavPhase _phase = NavPhase.toOrigin;
  bool _awaitingLocation = false;
  bool _pinDropMode = false;
  String _locationError = '';
  final TextEditingController _locationController = TextEditingController();

  StreamSubscription<Position>? _positionSub;
  Timer? _rerouteTimer;

  @override
  void initState() {
    super.initState();
    final s = widget.shipment;
    if (s != null &&
        _session.isActive &&
        _session.shipmentId == s.id) {
      _restoreSession();
    } else {
      _buildRoute();
    }
  }

  void _restoreSession() {
    _isNavigating = true;
    _phase = _session.phase;
    _originLatLng = _session.originLatLng;
    _destinationLatLng = _session.destinationLatLng;
    _currentLocation = _session.currentLocation;
    _routePoints = List.from(_session.routePoints);
    _eta = _session.eta;
    _distance = _session.distance;
    _nextInstruction = _session.nextInstruction;
    _nextRoad = _session.nextRoad;
    _instructionIcon = _session.instructionIcon;
    _loadingRoute = false;
    _awaitingLocation = false;
    _pinDropMode = false;
    _startGpsTracking();
  }

  void _saveSession() {
    final s = widget.shipment;
    if (s == null) return;
    _session.shipmentId = s.id;
    _session.isActive = true;
    _session.phase = _phase;
    _session.originLatLng = _originLatLng;
    _session.destinationLatLng = _destinationLatLng;
    _session.currentLocation = _currentLocation;
    _session.routePoints = List.from(_routePoints);
    _session.eta = _eta;
    _session.distance = _distance;
    _session.nextInstruction = _nextInstruction;
    _session.nextRoad = _nextRoad;
    _session.instructionIcon = _instructionIcon;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _rerouteTimer?.cancel();
    _locationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Geocoding
  // ═══════════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Route building
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _buildRoute() async {
    final origin = widget.shipment?.origin ?? 'Dallas, TX';
    final destination = widget.shipment?.destination ?? 'Atlanta, GA';

    LatLng? o = await _geocode(origin);
    LatLng? d = await _geocode(destination);
    o ??= await _geocode(origin.split(',').first.trim());
    d ??= await _geocode(destination.split(',').first.trim());

    if (o == null || d == null) {
      setState(() => _loadingRoute = false);
      return;
    }

    _originLatLng = o;
    _destinationLatLng = d;

    await _fetchOsrmRoute(o, d, updateState: true);
    setState(() => _loadingRoute = false);

    if (_routePoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final bounds = LatLngBounds.fromPoints(_routePoints);
          _mapController.fitCamera(
            CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(40, 100, 40, 300)),
          );
        }
      });
    }
  }

  Future<void> _fetchOsrmRoute(LatLng from, LatLng to,
      {bool updateState = false}) async {
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

      final steps = data['routes'][0]['legs'][0]['steps'] as List? ?? [];
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

      if (updateState) {
        setState(() {
          _routePoints = points;
          _eta = '$etaMin min';
          _distance = '$distMi mi';
        });
      } else {
        _routePoints = points;
        _eta = '$etaMin min';
        _distance = '$distMi mi';
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Turn instruction helpers
  // ═══════════════════════════════════════════════════════════════════════════

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
        return type.isNotEmpty
            ? type[0].toUpperCase() + type.substring(1)
            : 'Continue';
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

  // ═══════════════════════════════════════════════════════════════════════════
  // GPS tracking
  // ═══════════════════════════════════════════════════════════════════════════

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
        distanceFilter: 30,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final newLoc = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = newLoc);
      _session.currentLocation = newLoc;
      _mapController.move(newLoc, _mapController.camera.zoom);
    });

    _rerouteTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_currentLocation != null && _phase != NavPhase.arrived) {
        final target = _phase == NavPhase.toOrigin
            ? _originLatLng!
            : _destinationLatLng!;
        _fetchOsrmRoute(_currentLocation!, target, updateState: true)
            .then((_) {
          if (mounted) _saveSession();
        });
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Location dialog
  // ═══════════════════════════════════════════════════════════════════════════

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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your current city/state to calculate the route.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Houston, TX',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText:
                      _locationError.isNotEmpty ? _locationError : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('OR',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _useCurrentLocation(ctx),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Use Current Location',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('OR',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ]),
              const SizedBox(height: 12),
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
                  setDState(() => _locationError = 'Please enter a location');
                  return;
                }
                setDState(() => _locationError = '');
                Navigator.pop(ctx);
                setState(() {
                  _isNavigating = true;
                  _awaitingLocation = false;
                });
                final loc = await _geocode(input);
                if (!mounted) return;
                if (loc == null) {
                  setState(() {
                    _locationError = 'Could not find this location';
                    _awaitingLocation = true;
                    _isNavigating = false;
                  });
                  _showLocationDialog();
                  return;
                }
                setState(() => _currentLocation = loc);
                _saveSession();
                await _fetchOsrmRoute(loc, _originLatLng!, updateState: true);
                _startGpsTracking();
              },
              child: const Text('Start Navigation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation(BuildContext ctx) async {
    Navigator.pop(ctx);
    setState(() {
      _isNavigating = true;
      _awaitingLocation = false;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _awaitingLocation = true;
            _isNavigating = false;
          });
          _showLocationDialog();
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      final loc = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _currentLocation = loc);
      _saveSession();
      await _fetchOsrmRoute(loc, _originLatLng!, updateState: true);
      _startGpsTracking();
    } catch (_) {
      if (mounted) {
        setState(() {
          _awaitingLocation = true;
          _isNavigating = false;
        });
        _showLocationDialog();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Pin drop confirm
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _confirmDroppedPin() async {
    final center = _mapController.camera.center;
    setState(() {
      _pinDropMode = false;
      _currentLocation = center;
      _isNavigating = true;
      _awaitingLocation = false;
    });
    _saveSession();
    await _fetchOsrmRoute(center, _originLatLng!, updateState: true);
    _startGpsTracking();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Navigation actions
  // ═══════════════════════════════════════════════════════════════════════════

  void _onOpenNavigation() {
    _showLocationDialog();
  }

  void _onShipmentPickedUp() {
    setState(() {
      _phase = NavPhase.toDestination;
      _currentLocation = _originLatLng;
      _routePoints = [];
      _nextInstruction = '';
      _nextRoad = '';
    });
    _saveSession();
    _fetchOsrmRoute(_originLatLng!, _destinationLatLng!, updateState: true);
  }

  void _onEnRouteDelivery() {
    setState(() {
      _phase = NavPhase.arrived;
    });
    _saveSession();
  }

  Future<void> _onCompleteDelivery() async {
    final s = widget.shipment;
    if (s == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Complete Delivery?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Confirm that load ${s.loadId} has been delivered to ${s.destination}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _session.clear();
      await _shipmentService.completeShipment(s.id);
      await _notifService.notifyDeliveryCompleted(s.loadId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery completed! Added to order history.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cancelShipment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Shipment?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to cancel load '
            '${widget.shipment?.loadId ?? ''}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Shipment'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel Shipment'),
          ),
        ],
      ),
    );
    if (confirm == true && widget.shipment != null) {
      _session.clear();
      await _shipmentService.deleteShipment(widget.shipment!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Computed properties
  // ═══════════════════════════════════════════════════════════════════════════

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

  Color get _phaseColor {
    switch (_phase) {
      case NavPhase.toOrigin:
        return Colors.teal;
      case NavPhase.toDestination:
        return const Color(0xFF7C3AED);
      case NavPhase.arrived:
        return Colors.green;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final s = widget.shipment;
    final showNavCard = _isNavigating && !_pinDropMode && !_awaitingLocation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _originLatLng ?? const LatLng(33.0, -89.0),
              initialZoom: 5.5,
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
                      color: showNavCard ? _phaseColor : const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              MarkerLayer(markers: [
                if (_originLatLng != null)
                  Marker(
                    point: _originLatLng!,
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
                if (_destinationLatLng != null)
                  Marker(
                    point: _destinationLatLng!,
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
                if (_currentLocation != null && showNavCard)
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
              ]),
            ],
          ),

          if (_loadingRoute)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
            ),

          if (_pinDropMode) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Icon(Icons.push_pin, color: Color(0xFF7C3AED), size: 48,
                    shadows: [Shadow(color: Colors.white, blurRadius: 10)]),
              ),
            ),
            const Center(
              child: Icon(Icons.add, color: Colors.black54, size: 24),
            ),
          ],

          // Top header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                showNavCard ? _phaseTitle : 'Current Shipment',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              if (showNavCard &&
                                  !_loadingRoute &&
                                  !_awaitingLocation)
                                Text('$_distance \u00b7 $_eta',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (_isNavigating && !_pinDropMode)
                          GestureDetector(
                            onTap: _showLocationDialog,
                            child: const Icon(Icons.edit_location_alt,
                                color: Colors.white70),
                          ),
                        if (!_isNavigating)
                          ElevatedButton.icon(
                            onPressed: _cancelShipment,
                            icon: const Icon(Icons.cancel_outlined, size: 14),
                            label: const Text('Cancel',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Turn instruction card
                  if (showNavCard &&
                      !_loadingRoute &&
                      _nextInstruction.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
                              color: _phaseColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_instructionIcon,
                                color: _phaseColor, size: 26),
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
                                        color: Colors.grey, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Pin drop confirm button
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

          // Bottom card
          if (!_awaitingLocation && !_pinDropMode && !_loadingRoute)
            DraggableScrollableSheet(
              initialChildSize: showNavCard ? 0.40 : 0.55,
              minChildSize: showNavCard ? 0.20 : 0.25,
              maxChildSize: showNavCard ? 0.60 : 0.65,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 20)
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: showNavCard
                        ? _buildNavigationCardContent(s)
                        : _buildShipmentCardContent(s),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _buildShipmentCardContent(Shipment? s) {
    return [
      Center(
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: Colors.brown),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s?.loadId ?? '549SD00X87',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black)),
                      Text('${s?.commodity ?? 'Freight'} \u00b7 ${s?.status ?? 'Active'}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(s?.rate ?? '\$2,800',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black)),
              const Text('\u2191 \$3.50 / mi',
                  style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildRouteStep(
        location: s?.origin ?? 'Dallas, TX',
        date: s?.originDate ?? 'April 1, 2026 \u00b7 08:00',
        status: 'Pick up',
        isFirst: true,
        isActive: true,
      ),
      _buildRouteStep(
        location: s?.destination ?? 'Atlanta, GA',
        date: s?.destinationDate ?? 'April 2, 2026 \u00b7 14:30',
        status: 'Delivery',
        isFirst: false,
        isActive: false,
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          _buildStatItem(
              Icons.location_on_outlined, 'Distance', _distance),
          const SizedBox(width: 12),
          _buildStatItem(Icons.timer_outlined, 'Time', _eta),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _buildStatItem(Icons.shopping_cart_outlined, 'Weight',
              s?.weight ?? '38,500 lbs'),
          const SizedBox(width: 12),
          _buildStatItem(Icons.thermostat_outlined, 'Temp', '-4\u00b0C'),
        ],
      ),
      const SizedBox(height: 30),
      Row(
        children: [
          Container(
            width: 55, height: 55,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.phone_outlined, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _onOpenNavigation,
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
            width: 55, height: 55,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.description_outlined,
                color: Colors.black),
          ),
        ],
      ),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _buildNavigationCardContent(Shipment? s) {
    return [
      Center(
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text(
              _phase == NavPhase.arrived
                  ? 'Arrived!'
                  : 'ETA $_eta \u2014 On track',
              style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(s?.loadId ?? 'Shipment',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black)),
          Text(s?.rate ?? '',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black)),
        ],
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: _phase == NavPhase.toOrigin
            ? ElevatedButton.icon(
                onPressed: _onShipmentPickedUp,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Shipment Picked Up',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              )
            : _phase == NavPhase.toDestination
                ? ElevatedButton.icon(
                    onPressed: _onEnRouteDelivery,
                    icon: const Icon(Icons.navigation),
                    label: const Text('En Route to Delivery',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _onCompleteDelivery,
                    icon: const Icon(Icons.check),
                    label: const Text('Complete Booking',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _buildRouteStep({
    required String location,
    required String date,
    required String status,
    required bool isFirst,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(Icons.circle,
                  size: 12, color: isActive ? Colors.black : Colors.orange),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black)),
                Text(date,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(status,
                      style: TextStyle(
                        color: isActive ? Colors.blue : Colors.orange,
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
                  Text(label,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 10)),
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
