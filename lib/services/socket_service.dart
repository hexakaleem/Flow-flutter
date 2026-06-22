import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'token_service.dart';
import 'notification_service.dart';
import '../models/app_notification.dart';

class SocketService extends ChangeNotifier {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  final TokenService _tokens = TokenService();
  final NotificationService _notifications = NotificationService();

  static const String _socketUrl = 'http://52.39.196.46:3005';

  bool get isConnected => _socket?.connected ?? false;

  void init() async {
    final token = _tokens.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('[SOCKET] No token found, skipping connection');
      return;
    }

    if (_socket != null && _socket!.connected) {
      return;
    }

    _socket = IO.io(_socketUrl, IO.OptionBuilder()
      .setTransports(['websocket', 'polling'])
      .setAuth({'token': token})
      .enableReconnection()
      .setReconnectionDelay(1000)
      .setReconnectionAttempts(10)
      .build());

    _socket!.onConnect((_) {
      debugPrint('[SOCKET] Connected');
      notifyListeners();
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[SOCKET] Disconnected: $reason');
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      debugPrint('[SOCKET] Connect Error: $err');
    });

    // --- Listeners ---

    _socket!.on('booking:requested', (data) {
      _notifications.add(
        title: 'New Booking Request!',
        body: 'A carrier has requested to book your load.',
        type: NotificationType.generic,
      );
    });

    _socket!.on('booking:confirmed', (data) {
      final loadId = data['loadId']?.toString() ?? '';
      _notifications.add(
        title: 'Booking Confirmed! ✅',
        body: 'Your request for load #${loadId.toUpperCase().substring(loadId.length - 6)} was accepted.',
        type: NotificationType.loadBooked,
      );
    });

    _socket!.on('counteroffer:submitted', (data) {
      final loadId = data['loadId']?.toString() ?? '';
      final rate = data['proposedRate'];
      _notifications.add(
        title: 'New Counter-Offer 💸',
        body: 'You received a counter-offer of \$$rate for load #${loadId.toUpperCase().substring(loadId.length - 6)}',
        type: NotificationType.generic,
      );
    });

    _socket!.on('counteroffer:accepted', (data) {
      final loadId = data['loadId']?.toString() ?? '';
      _notifications.add(
        title: 'Counter-Offer Accepted! 🎉',
        body: 'Your counter-offer for load #${loadId.toUpperCase().substring(loadId.length - 6)} was accepted.',
        type: NotificationType.loadBooked,
      );
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    notifyListeners();
  }
}
