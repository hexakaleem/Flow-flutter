import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/shipment_service.dart';
import '../models/shipment.dart';

import '../widgets/custom_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  final ShipmentService _shipmentService = ShipmentService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Shipment> _shipments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShipments();
  }

  Future<void> _loadShipments() async {
    setState(() => _loading = true);
    final list = await _shipmentService.getCurrentUserShipments();
    setState(() {
      _shipments = list;
      _loading = false;
    });
  }

  Future<void> _openLoadBoard() async {
    if (_shipments.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot book more than one load at a time.')),
      );
      return;
    }
    await Navigator.pushNamed(context, '/load_board');
    await _loadShipments();
  }

  Future<void> _cancelShipment(Shipment s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Shipment?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to cancel load ${s.loadId}? This cannot be undone.'),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel Shipment'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _shipmentService.deleteShipment(s.id);
      await _loadShipments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shipment cancelled. You can now book a new load.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    }
  }

  void _onNavTap(int index) {
    if (index == 2) {
      _openLoadBoard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = _auth.currentUser?.username ?? 'Driver';
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentDate = '${months[now.month - 1]}, ${now.day.toString().padLeft(2, '0')}, ${now.year}';

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      backgroundColor: const Color(0xFFF8F9FA), // Light background
      body: Stack(
        children: [
          // Top Gradient Background
          Container(
            height: 350,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFCE9FFC),
                  Color(0xFFF8F9FA),
                ],
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadShipments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: const Color(0xFF1E1128),
                            child: Text(
                              username.isNotEmpty ? username[0].toUpperCase() : 'D',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1128),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'WELCOME ${username.toUpperCase()}!',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.search, size: 20, color: Colors.white70),
                                const SizedBox(width: 15),
                                const Icon(Icons.notifications, size: 20, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    // Date & Location
                    Text(
                      currentDate,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '5th Avenue, New York, NYC',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    // Current Shipment Header
                    const Text(
                      'Current Shipment',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(color: Colors.black),
                      )),
                    if (!_loading && _shipments.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text('No shipment available',
                                style: TextStyle(color: Colors.white70)),
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
                      _buildShipmentCard(_shipments.first), // Only show 1 load
                      
                    const SizedBox(height: 20),
                    
                    // Actions row (3 cards)
                    Row(
                      children: [
                        Expanded(child: _buildActionCard(Icons.local_gas_station, 'Fuel up')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildActionCard(Icons.history, 'Maintenance\nHistory')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildActionCard(Icons.payments, 'Earnings')),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Map Placeholder
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                        image: const DecorationImage(
                          image: AssetImage('assets/map.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 100), // padding for bottom nav
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

  Widget _buildShipmentCard(Shipment s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.loadId.isNotEmpty ? s.loadId : '-',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          const SizedBox(height: 2),
          Text(s.commodity.isNotEmpty ? s.commodity : '-',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1, thickness: 1),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked, color: Colors.white, size: 18),
                  Container(width: 2, height: 35, color: Colors.white24),
                  const Icon(Icons.radio_button_unchecked, color: Colors.white, size: 18),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.origin.isNotEmpty ? s.origin : '-',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                    Text(s.originDate.isNotEmpty ? s.originDate : '-',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 16),
                    Text(s.destination.isNotEmpty ? s.destination : '-',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                    Text(s.destinationDate.isNotEmpty ? s.destinationDate : '-',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/shipment_detail', arguments: s).then((_) => _loadShipments()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Go to Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _cancelShipment(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String label) {
    return Container(
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
    );
  }

  Widget _buildDrawer() {
    final user = _auth.currentUser;
    final String username = user?.username ?? 'Driver';
    final String initial = username.isNotEmpty ? username[0].toUpperCase() : 'D';

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
            title: const Text('Manage Profile', style: TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, '/profile');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              _auth.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
