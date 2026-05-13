import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';
import 'api_client.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _kKey = 'app_notifications';

  final ApiClient _api = ApiClient();

  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications.reversed.toList());

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  // ── Load from server (fallback to local cache) ──────────────────────────────

  Future<void> load() async {
    // Try server first
    try {
      final data = await _api.get('/notifications');
      if (data != null && data is List) {
        _notifications = data.map((e) {
          final json = e as Map<String, dynamic>;
          return AppNotification(
            id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
            title: json['title']?.toString() ?? '',
            body: json['message']?.toString() ?? json['body']?.toString() ?? '',
            type: _parseType(json['type']?.toString()),
            createdAt: json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
                : DateTime.now(),
            isRead: json['isRead'] == true,
          );
        }).toList();
        await _saveLocal();
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Failed to load server notifications: $e');
    }

    // Fallback to local cache
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

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(_notifications.map((n) => n.toJson()).toList()),
    );
  }

  NotificationType _parseType(String? type) {
    switch (type) {
      case 'account_created':
        return NotificationType.accountCreated;
      case 'vehicle_registered':
        return NotificationType.vehicleRegistered;
      case 'load_booked':
      case 'booking:confirmed':
        return NotificationType.loadBooked;
      case 'fuel_logged':
        return NotificationType.fuelLogged;
      case 'profile_updated':
        return NotificationType.profileUpdated;
      case 'delivery_completed':
        return NotificationType.deliveryCompleted;
      default:
        return NotificationType.generic;
    }
  }

  // ── Add (local convenience – also pushed by server via websocket later) ────

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
    await _saveLocal();
    notifyListeners();
  }

  // ── Mark read ──────────────────────────────────────────────────────────────

  Future<void> markRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    _notifications[idx].isRead = true;
    await _saveLocal();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    try {
      await _api.put('/notifications/mark-all-read');
    } catch (e) {
      debugPrint('Failed to mark all read on server: $e');
    }
    for (final n in _notifications) {
      n.isRead = true;
    }
    await _saveLocal();
    notifyListeners();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    try {
      await _api.delete('/notifications/$id');
    } catch (e) {
      debugPrint('Failed to delete notification on server: $e');
    }
    _notifications.removeWhere((n) => n.id == id);
    await _saveLocal();
    notifyListeners();
  }

  Future<void> clearAll() async {
    try {
      await _api.delete('/notifications');
    } catch (e) {
      debugPrint('Failed to clear notifications on server: $e');
    }
    _notifications.clear();
    await _saveLocal();
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

  Future<void> notifyDeliveryCompleted(String loadId) => add(
        title: '✅ Delivery Completed!',
        body: 'Load #$loadId has been delivered. Great job!',
        type: NotificationType.deliveryCompleted,
      );
}
