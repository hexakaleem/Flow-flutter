enum NotificationType {
  accountCreated,
  vehicleRegistered,
  loadBooked,
  fuelLogged,
  profileUpdated,
  deliveryCompleted,
  generic,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  // Icon + color per type
  static Map<NotificationType, ({String icon, String color})> get typeStyle => {
        NotificationType.accountCreated: (icon: '🎉', color: '4CAF50'),
        NotificationType.vehicleRegistered: (icon: '🚛', color: '7A3FF2'),
        NotificationType.loadBooked: (icon: '📦', color: '00BCD4'),
        NotificationType.fuelLogged: (icon: '⛽', color: 'FF9800'),
        NotificationType.profileUpdated: (icon: '✏️', color: '2196F3'),
        NotificationType.deliveryCompleted: (icon: '✅', color: '4CAF50'),
        NotificationType.generic: (icon: '🔔', color: '9E9E9E'),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.index,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: NotificationType.values[json['type'] as int],
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        isRead: json['isRead'] as bool,
      );
}
