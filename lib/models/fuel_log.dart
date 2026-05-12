class FuelLog {
  final String id;
  final double expense;
  final double quantity;
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime date;
  final String? receiptImagePath;

  const FuelLog({
    required this.id,
    required this.expense,
    required this.quantity,
    required this.location,
    this.latitude,
    this.longitude,
    required this.date,
    this.receiptImagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expense': expense,
      'quantity': quantity,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'date': date.toIso8601String(),
      'receiptImagePath': receiptImagePath,
    };
  }

  factory FuelLog.fromJson(Map<String, dynamic> json) {
    return FuelLog(
      id: json['id'] ?? '',
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      location: json['location'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      receiptImagePath: json['receiptImagePath'] as String?,
    );
  }
}
