import 'package:intl/intl.dart';

class Shipment {
  final String id;
  final String loadId;
  final String commodity;
  final String origin;
  final String destination;
  final String originDate;
  final String destinationDate;
  final String weight;
  final String rate;
  final String status;
  final String carrier;

  Shipment({
    required this.id,
    required this.loadId,
    required this.commodity,
    required this.origin,
    required this.destination,
    required this.originDate,
    required this.destinationDate,
    required this.weight,
    required this.rate,
    required this.status,
    required this.carrier,
  });

  /// Parse from a backend load object that is in booked/in_transit/delivered state.
  factory Shipment.fromJson(Map<String, dynamic> json) {
    String originCity = '';
    String destCity = '';

    if (json['origin'] is Map<String, dynamic>) {
      originCity = json['origin']['city'] ?? '';
    } else {
      originCity = json['origin']?.toString() ?? '';
    }

    if (json['destination'] is Map<String, dynamic>) {
      destCity = json['destination']['city'] ?? '';
    } else {
      destCity = json['destination']?.toString() ?? '';
    }

    String originDate = json['originDate']?.toString() ?? '';
    String destDate = json['destinationDate']?.toString() ?? '';

    if (json['pickupDate'] != null) {
      try {
        final dt = DateTime.parse(json['pickupDate']);
        originDate = DateFormat('MMM d').format(dt);
      } catch (_) {}
    }
    if (json['deliveryDate'] != null) {
      try {
        final dt = DateTime.parse(json['deliveryDate']);
        destDate = DateFormat('MMM d').format(dt);
      } catch (_) {}
    }

    String rate = json['rate']?.toString() ?? '';
    if (json['rate'] is num) {
      rate = '\$${NumberFormat('#,##0').format(json['rate'])}';
    }

    String weight = json['weight']?.toString() ?? '';
    if (json['weight'] is num) {
      weight = '${NumberFormat('#,##0').format(json['weight'])} lbs';
    }

    // Map backend status to UI status
    String status = json['status']?.toString() ?? '';
    switch (status) {
      case 'booked':
        status = 'Active';
        break;
      case 'in_transit':
        status = 'In Transit';
        break;
      case 'delivered':
        status = 'Delivered';
        break;
      case 'completed':
        status = 'Completed';
        break;
      case 'cancelled':
        status = 'Cancelled';
        break;
    }

    String loadNumber = json['loadNumber']?.toString() ?? '';
    if (loadNumber.isEmpty) {
      final idStr = json['_id']?.toString() ?? json['id']?.toString() ?? '';
      if (idStr.length >= 6) {
        loadNumber = '#FL-${idStr.substring(idStr.length - 6).toUpperCase()}';
      } else {
        loadNumber = '#FL-$idStr';
      }
    }

    return Shipment(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      loadId: loadNumber,
      commodity: json['commodity']?.toString() ?? 'General Freight',
      origin: originCity,
      destination: destCity,
      originDate: originDate,
      destinationDate: destDate,
      weight: weight,
      rate: rate,
      status: status,
      carrier: json['shipperName']?.toString() ?? json['carrier']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loadId': loadId,
      'commodity': commodity,
      'origin': origin,
      'destination': destination,
      'originDate': originDate,
      'destinationDate': destinationDate,
      'weight': weight,
      'rate': rate,
      'status': status,
      'carrier': carrier,
    };
  }
}
