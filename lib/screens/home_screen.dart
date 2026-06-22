import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/shipment_service.dart';
import '../services/notification_service.dart';
import '../services/api_client.dart';
import '../models/shipment.dart';
import '../models/vehicle_profile.dart';
import '../widgets/custom_bottom_nav.dart';
import 'shipment_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  final ShipmentService _shipmentService = ShipmentService();
  final NotificationService _notifService = NotificationService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Shipment> _shipments = [];
  VehicleProfile? _vehicleProfile;
  bool _loading = true;
  bool _showCongrats = false;
  bool _isOnDuty = false;
  String _locationText = 'Fetching location...';
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _fetchLocation();
    _startPeriodicLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _fetchAndSendLocation();
    });
  }

  Future<void> _loadHomeData() async {
    setState(() => _loading = true);
    final list = await _shipmentService.getCurrentUserShipments();
    final user = _auth.currentUser;
    final vehicleProfile =
        user == null ? null : _auth.getVehicleProfile(user.id);
    if (!mounted) return;
    setState(() {
      _shipments = list;
      _vehicleProfile = vehicleProfile;
      _loading = false;
    });
  }

  Future<void> _fetchLocation() async {
    await _fetchAndSendLocation();
  }

  Future<void> _fetchAndSendLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationText = 'Location unavailable');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          if (mounted) setState(() => _locationText = 'Permission denied');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationText = 'Permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium));
      final lat = pos.latitude;
      final lng = pos.longitude;

      // ── Send location to backend if truck is registered ─────────────────
      final truckId = _auth.truckId;
      if (truckId != null && truckId.isNotEmpty) {
        try {
          final api = ApiClient();
          await api.post('/fleet/trucks/$truckId/location', body: {
            'lat': lat,
            'lng': lng,
          });
        } catch (_) {
          // Non-critical — GPS tracking is best-effort
        }
      }

      // ── Reverse geocode for display ─────────────────────────────────────
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse'
          '?lat=${pos.latitude}&lon=${pos.longitude}&format=json');
      final res =
          await http.get(url, headers: {'User-Agent': 'FlowDriverApp/1.0'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final suburb =
            addr['suburb'] ?? addr['neighbourhood'] ?? addr['village'] ?? '';
        final city = addr['city'] ?? addr['town'] ?? addr['county'] ?? '';
        final parts =
            [suburb, city].where((s) => (s as String).isNotEmpty).toList();
        if (mounted) {
          setState(() => _locationText =
              parts.isNotEmpty ? parts.take(2).join(', ') : 'Location found');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _locationText = 'Location unavailable');
    }
  }

  Future<void> _navigateToVehicleRegistration() async {
    final result = await Navigator.pushNamed(context, '/vehicle_registration');
    if (result == true && mounted) {
      await _loadHomeData();
      _showCongratulations();
    }
  }

  void _showCongratulations() {
    setState(() => _showCongrats = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showCongrats = false);
      }
    });
  }

  Future<void> _openLoadBoard() async {
    if (_vehicleProfile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete vehicle registration before booking a load.'),
          backgroundColor: Colors.orange,
        ),
      );
      _navigateToVehicleRegistration();
      return;
    }

    if (_shipments.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You cannot book more than one load at a time.')),
      );
      return;
    }
    await Navigator.pushNamed(context, '/load_board');
    await _loadHomeData();
  }

  void _showEditVehicleSheet() {
    final profile = _vehicleProfile!;
    final formKey = GlobalKey<FormState>();

    final licensePlateController =
        TextEditingController(text: profile.licensePlate);
    final yearController = TextEditingController(text: profile.year);
    final makeController = TextEditingController(text: profile.make);
    final modelController = TextEditingController(text: profile.model);
    final maxWeightController = TextEditingController(text: profile.maxWeight);
    final trailerLengthController =
        TextEditingController(text: profile.trailerLength);
    final trailerWidthController =
        TextEditingController(text: profile.trailerWidth);
    final trailerHeightController =
        TextEditingController(text: profile.trailerHeight);

    String equipmentType = profile.equipmentType;
    bool hasLiftgate = profile.hasLiftgate;
    bool isHazmatCertified = profile.isHazmatCertified;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E5AF7).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_outlined,
                            color: Color(0xFF7A3FF2)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Vehicle',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value:
                                equipmentType.isNotEmpty ? equipmentType : null,
                            hint: const Text('Not Selected',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 14)),
                            dropdownColor: Colors.white,
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Equipment Type',
                              labelStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF7F6FB),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200)),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Flatbed',
                                  child: Text('Flatbed',
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14))),
                              DropdownMenuItem(
                                  value: 'Dry Van',
                                  child: Text('Dry Van',
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14))),
                              DropdownMenuItem(
                                  value: 'Reefer',
                                  child: Text('Reefer',
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14))),
                              DropdownMenuItem(
                                  value: 'Step Deck',
                                  child: Text('Step Deck',
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14))),
                              DropdownMenuItem(
                                  value: 'Other',
                                  child: Text('Other',
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14))),
                            ],
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Required'
                                    : null,
                            onChanged: (v) => equipmentType = v!,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildEditField(
                                    'License Plate', licensePlateController,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : RegExp(r'^[a-zA-Z0-9]+$')
                                                    .hasMatch(v.trim())
                                                ? null
                                                : 'Alphanumeric only'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildEditField('Year', yearController,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditField('Make', makeController,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEditField('Model', modelController,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Required'
                                            : null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildEditField(
                              'Max Weight (lbs)', maxWeightController,
                              validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            if (!RegExp(r'^\d{1,7}$').hasMatch(v.trim())) {
                              return 'Max 7 digits';
                            }
                            return null;
                          }),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditField('Trailer Length (ft)',
                                    trailerLengthController),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEditField('Trailer Width (ft)',
                                    trailerWidthController, validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (!RegExp(r'^\d{1,3}$')
                                      .hasMatch(v.trim())) {
                                    return 'Max 3 digits';
                                  }
                                  return null;
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildEditField(
                              'Trailer Height (ft)', trailerHeightController,
                              validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            if (!RegExp(r'^\d{1,3}$').hasMatch(v.trim())) {
                              return 'Max 3 digits';
                            }
                            return null;
                          }),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditToggle(
                                    'Liftgate',
                                    hasLiftgate,
                                    (v) =>
                                        setSheetState(() => hasLiftgate = v)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEditToggle(
                                    'Hazmat Certified',
                                    isHazmatCertified,
                                    (v) => setSheetState(
                                        () => isHazmatCertified = v)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) return;
                                      setSheetState(() => isSaving = true);
                                      final updatedProfile = VehicleProfile(
                                        equipmentType: equipmentType,
                                        licensePlate:
                                            licensePlateController.text.trim(),
                                        state: profile.state,
                                        vinNumber: profile.vinNumber,
                                        year: yearController.text.trim(),
                                        make: makeController.text.trim(),
                                        model: modelController.text.trim(),
                                        trailerLength:
                                            trailerLengthController.text.trim(),
                                        trailerWidth:
                                            trailerWidthController.text.trim(),
                                        trailerHeight:
                                            trailerHeightController.text.trim(),
                                        maxWeight:
                                            maxWeightController.text.trim(),
                                        internalFleetId:
                                            profile.internalFleetId,
                                        registrationDocumentLabel:
                                            profile.registrationDocumentLabel,
                                        registrationDocumentType:
                                            profile.registrationDocumentType,
                                        insuranceDocumentLabel:
                                            profile.insuranceDocumentLabel,
                                        insuranceDocumentType:
                                            profile.insuranceDocumentType,
                                        registrationDocumentPath:
                                            profile.registrationDocumentPath,
                                        insuranceDocumentPath:
                                            profile.insuranceDocumentPath,
                                        hasLiftgate: hasLiftgate,
                                        isHazmatCertified: isHazmatCertified,
                                      );
                                      final user = _auth.currentUser;
                                      if (user == null) return;
                                      final saved =
                                          await _auth.saveVehicleProfile(
                                              userId: user.id,
                                              profile: updatedProfile);
                                      if (!mounted || !ctx.mounted) return;
                                      if (saved) {
                                        Navigator.pop(ctx);
                                        await _loadHomeData();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('Vehicle updated!'),
                                              backgroundColor: Colors.teal,
                                            ),
                                          );
                                        }
                                      } else {
                                        setSheetState(() => isSaving = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to save.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8E5AF7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Save Changes',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == 1) {
      Navigator.pushNamed(context, '/order_history');
    } else if (index == 2) {
      _openLoadBoard();
    } else if (index == 3) {
      Navigator.pushNamed(context, '/stats');
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = _auth.currentUser?.username ?? 'Driver';
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final currentDate = '${now.day} ${months[now.month - 1]}, ${now.year}';

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Container(
            height: 350,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFCE9FFC), Color(0xFFF8F9FA)],
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadHomeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status bar ──────────────────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFF1E1128),
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : 'D',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Image.asset(
                          'assets/logo.png',
                          height: 36,
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/search'),
                          child: Icon(Icons.search,
                              size: 22, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 14),
                        // ── Notification bell with unread badge ──────────────
                        ListenableBuilder(
                          listenable: _notifService,
                          builder: (context, _) {
                            return GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, '/notifications'),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(Icons.notifications_none_rounded,
                                      size: 22, color: Colors.grey.shade700),
                                  if (_notifService.hasUnread)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // ── Welcome card ─────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1128),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, $username!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded,
                                            size: 14, color: Color(0xFFCE9FFC)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _locationText,
                                            style: const TextStyle(
                                              color: Color(0xFFCE9FFC),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded,
                                            size: 13, color: Colors.white54),
                                        const SizedBox(width: 4),
                                        Text(
                                          currentDate,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    _isOnDuty ? 'On Duty' : 'Off Duty',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _isOnDuty
                                          ? const Color(0xFFCE9FFC)
                                          : Colors.white38,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _isOnDuty = !_isOnDuty),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      width: 56,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        color: _isOnDuty
                                            ? const Color(0xFF7A3FF2)
                                            : Colors.white24,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AnimatedPositioned(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            left: _isOnDuty ? null : 3,
                                            right: _isOnDuty ? 3 : null,
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Quick-action tiles (always visible) ──────────────────
                    Row(
                      children: [
                        Expanded(
                            child: _buildActionCard(
                                Icons.local_gas_station, 'Fuel Log',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/fuel_log'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildActionCard(
                                Icons.task_alt_rounded, 'Tasks',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/tasks'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildActionCard(
                                Icons.support_agent_rounded, 'Support',
                                onTap: () => Navigator.pushNamed(
                                    context, '/customer_support'))),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // ── Current Shipment ─────────────────────────────────────
                    const Text(
                      'Current Shipment',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: Colors.black),
                      )),
                    if (!_loading && _shipments.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC07BFE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text('No shipment available',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _openLoadBoard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Browse Loads'),
                            )
                          ],
                        ),
                      ),
                    if (!_loading && _shipments.isNotEmpty)
                      _buildShipmentCard(_shipments.first),
                    const SizedBox(height: 20),
                    const Text(
                      'Vehicle Info',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_loading && _vehicleProfile == null)
                      _buildProfileProgressCard(),
                    if (!_loading && _vehicleProfile != null)
                      _buildVehicleInfoCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          if (_showCongrats)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E5AF7).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.celebration,
                          size: 60,
                          color: Color(0xFF8E5AF7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Congratulations!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1128),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Profile 100% Complete',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E5AF7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You can now book loads and start earning!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _buildProfileProgressCard() {
    return GestureDetector(
      onTap: _navigateToVehicleRegistration,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFE8E1FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_shipping_outlined,
                      color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Your Profile',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Register your vehicle to start booking loads.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black54),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text(
                  '50% Profile Completed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                Text(
                  '50%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: 0.5,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildProgressStep('Account Setup', true),
                const SizedBox(width: 8),
                _buildProgressStep('Vehicle Reg.', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(String label, bool completed) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: completed ? Colors.green : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: completed
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: completed ? Colors.green : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoCard() {
    final profile = _vehicleProfile!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8E1FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E5AF7).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_outlined,
                    color: Color(0xFF7A3FF2)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'This driver is cleared to book loads.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _showEditVehicleSheet,
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildVehicleSummaryChip(
                        'Equipment', profile.equipmentType,
                        accent: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        _buildVehicleSummaryChip('Plate', profile.licensePlate),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildVehicleSummaryChip('VIN', profile.vinNumber),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildVehicleSummaryChip('Year', profile.year),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildVehicleSummaryChip(
                        'Make / Model', '${profile.make} ${profile.model}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildVehicleSummaryChip('Trailer',
                        '${profile.trailerLength} x ${profile.trailerWidth} x ${profile.trailerHeight} ft'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildVehicleSummaryChip(
                        'Max Weight', '${profile.maxWeight} lbs'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildVehicleSummaryChip(
                        'Registration Doc',
                        profile.registrationDocumentLabel.isNotEmpty
                            ? profile.registrationDocumentLabel
                            : 'Not uploaded'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildVehicleSummaryChip(
                        'Insurance Doc',
                        profile.insuranceDocumentLabel.isNotEmpty
                            ? profile.insuranceDocumentLabel
                            : 'Not uploaded'),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSummaryChip(String label, String value,
      {bool accent = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent
            ? const Color(0xFF8E5AF7).withOpacity(0.12)
            : const Color(0xFFF7F6FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: accent
                ? const Color(0xFF8E5AF7).withOpacity(0.2)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent ? const Color(0xFF7A3FF2) : Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller,
      {String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
            fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF7F6FB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF8E5AF7), width: 1.5)),
      ),
    );
  }

  Widget _buildEditToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF8E5AF7).withOpacity(0.12)
              : const Color(0xFFF7F6FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value ? const Color(0xFF8E5AF7) : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(value ? Icons.check_box : Icons.check_box_outline_blank,
                color: value ? const Color(0xFF7A3FF2) : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: value ? const Color(0xFF7A3FF2) : Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _goToMap(Shipment s) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShipmentDetailScreen(shipment: s),
      ),
    );
    await _loadHomeData();
  }

  Widget _buildShipmentCard(Shipment s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFC07BFE),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC07BFE).withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.loadId.isNotEmpty ? s.loadId : '-',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18)),
          const SizedBox(height: 2),
          Text(s.commodity.isNotEmpty ? s.commodity : '-',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          const Divider(color: Colors.white30, height: 1, thickness: 1),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked,
                      color: Colors.white, size: 18),
                  Container(width: 2, height: 35, color: Colors.white30),
                  const Icon(Icons.radio_button_unchecked,
                      color: Colors.white, size: 18),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.origin.isNotEmpty ? s.origin : '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15)),
                    Text(s.originDate.isNotEmpty ? s.originDate : '-',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 16),
                    Text(s.destination.isNotEmpty ? s.destination : '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15)),
                    Text(s.destinationDate.isNotEmpty ? s.destinationDate : '-',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => _goToMap(s),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Go to Map',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = _auth.currentUser;
    final String username = user?.username ?? 'Driver';
    final String initial =
        username.isNotEmpty ? username[0].toUpperCase() : 'D';

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC07BFE), Color(0xFF8A30FA)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A30FA),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                Text(
                  user?.email ?? 'driver@flow.com',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.black87),
            title: const Text('Manage Profile',
                style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final nav = Navigator.of(context);
              await _auth.logout();
              nav.pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
