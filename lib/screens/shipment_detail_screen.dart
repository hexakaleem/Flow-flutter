import 'package:flutter/material.dart';
import '../models/shipment.dart';

class ShipmentDetailScreen extends StatelessWidget {
  final Shipment? shipment;

  const ShipmentDetailScreen({super.key, this.shipment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map Background Placeholder — offline friendly
          Container(
            height: 400,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B2735),
                  Color(0xFF0D1B2A),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Decorative road lines
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: Colors.white10),
                ),
                Positioned(
                  top: 140,
                  left: 30,
                  right: 30,
                  child: Container(height: 1, color: Colors.white10),
                ),
                Positioned(
                  top: 200,
                  left: 0,
                  right: 80,
                  child: Container(height: 1, color: Colors.white10),
                ),
                Positioned(
                  top: 260,
                  left: 60,
                  right: 0,
                  child: Container(height: 1, color: Colors.white10),
                ),
                // Route dots
                Positioned(
                  top: 160,
                  left: 60,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 280,
                  right: 80,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Custom AppBar
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.8),
                        child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            'Current Shipment',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Content Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          spreadRadius: 5),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Price
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
                                child: const Icon(Icons.inventory_2_outlined,
                                    color: Colors.brown),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(shipment?.loadId ?? '549SD00X87',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: Colors.black)),
                                  Text(
                                      '${shipment?.commodity ?? 'Fruits & Vegetables'} · Reefer',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(shipment?.rate ?? '\$2,800',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: Colors.black)),
                              const Text('↑ \$3.50 / mi',
                                  style: TextStyle(
                                      color: Colors.green, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Route Progress
                      _buildRouteStep('Dallas, TX', 'April 1, 2026 · 08:00',
                          'Picked up', true),
                      _buildRouteStep('Atlanta, GA', 'April 2, 2026 · 14:30',
                          'En route', false),

                      const SizedBox(height: 30),

                      // Stats Grid
                      Row(
                        children: [
                          _buildStatItem(
                              Icons.location_on_outlined, 'Distance', '781 mi'),
                          const SizedBox(width: 15),
                          _buildStatItem(
                              Icons.timer_outlined, 'Time left', '4h 20m'),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          _buildStatItem(Icons.shopping_cart_outlined, 'Weight',
                              '38,500 lbs'),
                          const SizedBox(width: 15),
                          _buildStatItem(
                              Icons.thermostat_outlined, 'Temp', '-4°C'),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Bottom Actions
                      Row(
                        children: [
                          _buildIconButton(Icons.phone_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.send),
                              label: const Text('Open Navigation'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildIconButton(Icons.description_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStep(
      String location, String date, String status, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(Icons.circle,
                  size: 12, color: isCompleted ? Colors.black : Colors.orange),
              if (!isCompleted)
                Container(width: 2, height: 40, color: Colors.grey.shade200),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black)),
                Text(date,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.blue.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isCompleted ? Colors.blue : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: Colors.red.shade300),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 10)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(icon, color: Colors.black),
    );
  }
}
