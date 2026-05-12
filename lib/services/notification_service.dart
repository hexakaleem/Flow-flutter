import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _kKey = 'app_notifications';

  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  // ── Load from prefs ────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _notifications =
          list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(_notifications.map((n) => n.toJson()).toList()),
    );
  }

  // ── Add ────────────────────────────────────────────────────────────────────

  Future<void> add({
    required String title,
    required String body,
    required NotificationType type,
  }) async {
    // Avoid duplicate notifications of same type within 5 seconds
    final now = DateTime.now();
    final recent = _notifications.where((n) =>
        n.type == type &&
        now.difference(n.createdAt).inSeconds < 5);
    if (recent.isNotEmpty) return;

    _notifications.add(AppNotification(
      id: 'notif_${now.millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      createdAt: now,
    ));
    await _save();
    notifyListeners();
  }

  // ── Mark read ──────────────────────────────────────────────────────────────

  Future<void> markRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notifications[idx].isRead = true;
    await _save();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (final n in _notifications) {
      n.isRead = true;
    }
    await _save();
    notifyListeners();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _save();
    notifyListeners();
  }

  // ── Convenience factory methods ────────────────────────────────────────────

  Future<void> notifyAccountCreated(String username) => add(
        title: '🎉 Welcome, $username!',
        body:
            'Your FLOW account has been created. Register your vehicle to start booking loads.',
        type: NotificationType.accountCreated,
      );

  Future<void> notifyVehicleRegistered() => add(
        title: '🚛 Vehicle Registered!',
        body:
            'Congratulations! Your vehicle has been registered. You are now cleared to book loads.',
        type: NotificationType.vehicleRegistered,
      );

  Future<void> notifyLoadBooked(String loadId) => add(
        title: '📦 Load Booked!',
        body: 'You have successfully booked load #$loadId. Safe travels!',
        type: NotificationType.loadBooked,
      );

  Future<void> notifyFuelLogged() => add(
        title: '⛽ Fuel Log Added',
        body: 'Your fuel expense has been recorded successfully.',
        type: NotificationType.fuelLogged,
      );
}
