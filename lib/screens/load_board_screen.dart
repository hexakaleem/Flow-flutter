import 'package:flutter/material.dart';
import '../models/load.dart';
import '../services/load_service.dart';
import '../widgets/custom_bottom_nav.dart';

class LoadBoardScreen extends StatefulWidget {
  const LoadBoardScreen({super.key});

  @override
  State<LoadBoardScreen> createState() => _LoadBoardScreenState();
}

class _LoadBoardScreenState extends State<LoadBoardScreen> {
  late Future<List<Load>> _loadsFuture;
  final LoadService _loadService = LoadService();
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadsFuture = _loadService.getAvailableLoads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
                  Color(0xFFC07BFE),
                  Color(0xFFF8F9FA),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1128),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Row(
                      children: [
                         Expanded(
                          child: Text(
                            'Load Board',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.black),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Colors.grey),
                        hintText: 'Search origin, destination...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFilterPill('All'),
                      _buildFilterPill('Best Pay'),
                      _buildFilterPill('Nearby'),
                      _buildFilterPill('Flatbed'),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '🔥 EXPIRING SOON',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Load List
                Expanded(
                  child: FutureBuilder<List<Load>>(
                    future: _loadsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final loads = snapshot.data ?? [];

                      var filteredLoads = loads.where((l) {
                        if (_searchQuery.isEmpty) return true;
                        return l.origin.toLowerCase().contains(_searchQuery) ||
                            l.destination
                                .toLowerCase()
                                .contains(_searchQuery) ||
                            l.commodity.toLowerCase().contains(_searchQuery) ||
                            l.loadNumber.toLowerCase().contains(_searchQuery);
                      }).toList();

                      if (_selectedFilter == 'Best Pay') {
                        filteredLoads.sort((a, b) {
                          double rateA = double.tryParse(
                                  a.rate.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                              0;
                          double rateB = double.tryParse(
                                  b.rate.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                              0;
                          return rateB.compareTo(rateA);
                        });
                      } else if (_selectedFilter == 'Flatbed') {
                        filteredLoads = filteredLoads.where((l) {
                          return l.status.toLowerCase().contains('flatbed') ||
                              l.requirements.any(
                                  (r) => r.toLowerCase().contains('flatbed'));
                        }).toList();
                      } else if (_selectedFilter == 'Nearby') {
                        filteredLoads = filteredLoads
                            .where((l) => l.distance.toLowerCase().contains('km'))
                            .toList();
                      }

                      if (filteredLoads.isEmpty) {
                        return const Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(
                            left: 20, right: 20, bottom: 100),
                        itemCount: filteredLoads.length,
                        itemBuilder: (context, index) {
                          return _buildLoadCard(filteredLoads[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/home');
          if (index == 1) Navigator.pushNamed(context, '/order_history');
          if (index == 3) Navigator.pushNamed(context, '/stats');
        },
      ),
    );
  }

  Widget _buildFilterPill(String title) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = title),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isSelected)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
          ],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadCard(Load load) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(load.loadNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Icon(Icons.bolt,
                            color: Colors.orange.shade400, size: 14),
                        Text('1h left',
                            style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(load.rate,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('↑ ${load.rateUnit}',
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  Text(load.distance,
                      style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),

          // Route
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(load.origin,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(load.originState,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text('${load.originDate} • ${load.originTime}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.teal),
                      Container(
                          width: 40, height: 2, color: Colors.grey.shade300),
                      const Icon(Icons.circle, size: 8, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.local_shipping,
                      color: Colors.green, size: 16),
                  Text(load.distance,
                      style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(load.destination,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(load.destinationState,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text('${load.destinationDate} • ${load.destinationTime}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoPill(load.status, Colors.teal.shade50, Colors.teal),
              ...load.requirements
                  .map((req) => _buildInfoPill(req, Colors.blue.shade50, Colors.blue)),
              _buildInfoPill(load.weight, Colors.grey.shade100, Colors.black87),
              _buildInfoPill(
                  load.commodity, Colors.orange.shade50, Colors.orange),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 10),

          // Broker & Actions
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                    color: Colors.teal, borderRadius: BorderRadius.circular(8)),
                child: const Center(
                    child: Text('CH',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cargohub Brokers',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.orange, size: 12),
                        Text(' 4.9 • 312 loads',
                            style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.phone, color: Colors.green, size: 18),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/load_details',
                    arguments: load),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                child: const Text('Load Details',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoPill(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
