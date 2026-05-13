import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _svc = NotificationService();

  // Filter: 'all' | 'unread'
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _svc.addListener(_rebuild);
  }

  @override
  void dispose() {
    _svc.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  List<AppNotification> get _displayed {
    final all = _svc.notifications;
    if (_filter == 'unread') return all.where((n) => !n.isRead).toList();
    return all;
  }

  // ── Time-ago helper ───────────────────────────────────────────────────────
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  // ── Per-type icon data ────────────────────────────────────────────────────
  ({IconData icon, Color bg, Color fg}) _iconData(NotificationType type) {
    switch (type) {
      case NotificationType.accountCreated:
        return (
          icon: Icons.celebration_rounded,
          bg: const Color(0xFF4CAF50),
          fg: Colors.white
        );
      case NotificationType.vehicleRegistered:
        return (
          icon: Icons.local_shipping_rounded,
          bg: const Color(0xFF7A3FF2),
          fg: Colors.white
        );
      case NotificationType.loadBooked:
        return (
          icon: Icons.inventory_2_rounded,
          bg: const Color(0xFF00BCD4),
          fg: Colors.white
        );
      case NotificationType.fuelLogged:
        return (
          icon: Icons.local_gas_station_rounded,
          bg: const Color(0xFFFF9800),
          fg: Colors.white
        );
      case NotificationType.profileUpdated:
        return (
          icon: Icons.edit_rounded,
          bg: const Color(0xFF2196F3),
          fg: Colors.white
        );
      case NotificationType.deliveryCompleted:
        return (
          icon: Icons.check_circle_rounded,
          bg: const Color(0xFF4CAF50),
          fg: Colors.white
        );
      case NotificationType.generic:
        return (
          icon: Icons.notifications_rounded,
          bg: const Color(0xFF9E9E9E),
          fg: Colors.white
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _displayed;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // ── Gradient header ───────────────────────────────────────────────
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
              children: [
                // ── App bar pill ───────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                            'Notifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_svc.notifications.isNotEmpty) ...[
                          if (_svc.hasUnread) ...[
                            GestureDetector(
                              onTap: () async => await _svc.markAllRead(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7A3FF2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Mark all read',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Clear all?'),
                                  content: const Text(
                                      'Are you sure you want to delete all notifications?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Clear',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _svc.clearAll();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Clear all',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Filter chips ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 10),
                      _FilterChip(
                        label: 'Unread',
                        selected: _filter == 'unread',
                        badge: _svc.unreadCount > 0
                            ? '${_svc.unreadCount}'
                            : null,
                        onTap: () => setState(() => _filter = 'unread'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── List ───────────────────────────────────────────────────
                Expanded(
                  child: items.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final notif = items[i];
                            final style = _iconData(notif.type);
                            final isNew = !notif.isRead;

                            return Dismissible(
                              key: Key(notif.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white, size: 22),
                              ),
                              onDismissed: (_) => _svc.delete(notif.id),
                              child: GestureDetector(
                                onTap: () => _svc.markRead(notif.id),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isNew
                                        ? const Color(0xFFEFE8FF)
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isNew
                                          ? const Color(0xFFCEB5FF)
                                          : const Color(0xFFEEEEEE),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Icon circle
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: style.bg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(style.icon,
                                            color: style.fg, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    notif.title,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: isNew
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      color: const Color(
                                                          0xFF1E1128),
                                                    ),
                                                  ),
                                                ),
                                                if (isNew)
                                                  Container(
                                                    width: 9,
                                                    height: 9,
                                                    margin:
                                                        const EdgeInsets
                                                            .only(left: 6),
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Color(
                                                          0xFF7A3FF2),
                                                      shape:
                                                          BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _timeAgo(notif.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    Colors.grey.shade500,
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              notif.body,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isNew
                                                    ? const Color(
                                                        0xFF2D1B69)
                                                    : Colors.grey.shade600,
                                                fontWeight:
                                                    FontWeight.w500,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final isUnread = _filter == 'unread';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUnread
                ? Icons.mark_email_read_rounded
                : Icons.notifications_none_rounded,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isUnread ? 'All caught up!' : 'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          if (isUnread)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'You have no unread notifications.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Filter chip widget ────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E1128) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? const Color(0xFF1E1128)
                : Colors.grey.shade300,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF7A3FF2)
                      : const Color(0xFFCE9FFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
