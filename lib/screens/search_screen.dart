import 'package:flutter/material.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
class _AppDestination {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final List<String> keywords;

  const _AppDestination({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.keywords,
  });
}

// ── All searchable destinations ───────────────────────────────────────────────
const List<_AppDestination> _allDestinations = [
  _AppDestination(
    title: 'Fuel Log',
    subtitle: 'Record and track fuel expenses',
    icon: Icons.local_gas_station_rounded,
    route: '/fuel_log',
    keywords: ['fuel', 'log', 'gas', 'petrol', 'expense', 'refill'],
  ),
  _AppDestination(
    title: 'Customer Support',
    subtitle: 'Chat with AI support assistant',
    icon: Icons.support_agent_rounded,
    route: '/customer_support',
    keywords: ['support', 'help', 'chat', 'ai', 'assistant', 'customer'],
  ),
  _AppDestination(
    title: 'Load Board',
    subtitle: 'Browse and book available loads',
    icon: Icons.inventory_2_outlined,
    route: '/load_board',
    keywords: ['load', 'board', 'book', 'cargo', 'freight', 'browse'],
  ),
  _AppDestination(
    title: 'Stats',
    subtitle: 'View your performance insights',
    icon: Icons.bar_chart_rounded,
    route: '/stats',
    keywords: ['stats', 'statistics', 'performance', 'insights', 'analytics'],
  ),
  _AppDestination(
    title: 'Profile',
    subtitle: 'Manage your driver profile',
    icon: Icons.person_outline_rounded,
    route: '/profile',
    keywords: ['profile', 'account', 'driver', 'settings', 'edit'],
  ),
  _AppDestination(
    title: 'Vehicle Registration',
    subtitle: 'Register or update your vehicle',
    icon: Icons.local_shipping_outlined,
    route: '/vehicle_registration',
    keywords: ['vehicle', 'truck', 'registration', 'vin', 'plate', 'trailer'],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<_AppDestination> _results = [];

  @override
  void initState() {
    super.initState();
    _results = _allDestinations; // show all by default
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _results = _allDestinations);
      return;
    }
    setState(() {
      _results = _allDestinations.where((d) {
        return d.title.toLowerCase().contains(q) ||
            d.subtitle.toLowerCase().contains(q) ||
            d.keywords.any((k) => k.contains(q));
      }).toList();
    });
  }

  void _navigate(_AppDestination dest) {
    Navigator.pushNamed(context, dest.route);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Purple gradient header ──────────────────────────────────────
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: back + search bar ────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey.shade400, size: 20),
                              suffixIcon: hasQuery
                                  ? GestureDetector(
                                      onTap: () => _controller.clear(),
                                      child: Icon(Icons.close,
                                          color: Colors.grey.shade400,
                                          size: 18),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ─────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section label
                        Text(
                          hasQuery ? 'Results' : 'Quick Actions',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E1128),
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (_results.isEmpty)
                          _buildEmpty()
                        else if (!hasQuery)
                          // Chip grid (mockup style)
                          _buildChipGrid()
                        else
                          // Detailed list for search results
                          _buildResultList(),
                      ],
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

  // ── Chip grid (default / no query) ───────────────────────────────────────
  Widget _buildChipGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _allDestinations
          .map((dest) => _QuickChip(
                label: dest.title,
                icon: dest.icon,
                onTap: () => _navigate(dest),
              ))
          .toList(),
    );
  }

  // ── Detailed result list ──────────────────────────────────────────────────
  Widget _buildResultList() {
    return Column(
      children: _results
          .map((dest) => _ResultTile(dest: dest, onTap: () => _navigate(dest)))
          .toList(),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick chip widget ─────────────────────────────────────────────────────────
class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE5E5E5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF7A3FF2)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E1128),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Result tile widget ────────────────────────────────────────────────────────
class _ResultTile extends StatelessWidget {
  final _AppDestination dest;
  final VoidCallback onTap;

  const _ResultTile({required this.dest, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFEBFF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8E5AF7).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(dest.icon,
                  size: 20, color: const Color(0xFF7A3FF2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dest.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1128),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dest.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
