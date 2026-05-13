import 'package:intl/intl.dart';

class Load {
  final String id;
  final String loadNumber;
  final String rate;
  final String rateUnit;
  final String commodity;
  final String origin;
  final String originState;
  final String originDate;
  final String originTime;
  final String destination;
  final String destinationState;
  final String destinationDate;
  final String destinationTime;
  final String weight;
  final String distance;
  final String status;
  final List<String> requirements;

  Load({
    required this.id,
    required this.loadNumber,
    required this.rate,
    required this.rateUnit,
    required this.commodity,
    required this.origin,
    required this.originState,
    required this.originDate,
    required this.originTime,
    required this.destination,
    required this.destinationState,
    required this.destinationDate,
    required this.destinationTime,
    required this.weight,
    required this.distance,
    required this.status,
    required this.requirements,
  });

  /// Parse from the backend API response (load or marketplace load object).
  factory Load.fromJson(Map<String, dynamic> json) {
    // The backend may return nested origin/destination objects or flat strings.
    String originCity = '';
    String originState = '';
    String destCity = '';
    String destState = '';

    if (json['origin'] is Map<String, dynamic>) {
      final o = json['origin'] as Map<String, dynamic>;
      originCity = o['city'] ?? '';
      originState = '${o['state'] ?? ''}, USA';
    } else {
      originCity = json['origin']?.toString() ?? '';
      originState = json['originState']?.toString() ?? '';
    }

    if (json['destination'] is Map<String, dynamic>) {
      final d = json['destination'] as Map<String, dynamic>;
      destCity = d['city'] ?? '';
      destState = '${d['state'] ?? ''}, USA';
    } else {
      destCity = json['destination']?.toString() ?? '';
      destState = json['destinationState']?.toString() ?? '';
    }

    // Parse dates
    String originDate = json['originDate']?.toString() ?? '';
    String originTime = json['originTime']?.toString() ?? '';
    String destDate = json['destinationDate']?.toString() ?? '';
    String destTime = json['destinationTime']?.toString() ?? '';

    if (json['pickupDate'] != null) {
      try {
        final dt = DateTime.parse(json['pickupDate']);
        originDate = DateFormat('MMM d').format(dt);
        originTime = DateFormat('HH:mm').format(dt);
      } catch (_) {}
    }
    if (json['deliveryDate'] != null) {
      try {
        final dt = DateTime.parse(json['deliveryDate']);
        destDate = DateFormat('MMM d').format(dt);
        destTime = DateFormat('HH:mm').format(dt);
      } catch (_) {}
    }

    // Parse rate
    String rate = json['rate']?.toString() ?? '\$0';
    String rateUnit = json['rateUnit']?.toString() ?? '';
    if (json['rate'] is num) {
      final rateNum = (json['rate'] as num).toDouble();
      rate = '\$${NumberFormat('#,##0').format(rateNum)}';
      // Compute rate per mile if distance is available
      if (json['distance'] is num && (json['distance'] as num) > 0) {
        final perMile = rateNum / (json['distance'] as num);
        rateUnit = '\$${perMile.toStringAsFixed(2)}/mi';
      }
    }

    // Parse weight
    String weight = json['weight']?.toString() ?? '';
    if (json['weight'] is num) {
      weight = '${NumberFormat('#,##0').format(json['weight'])} lbs';
    }

    // Parse distance
    String distance = json['distance']?.toString() ?? '';
    if (json['distance'] is num) {
      distance = '${NumberFormat('#,##0').format(json['distance'])} mi';
    }

    // Parse truck type / status
    String status = json['status']?.toString() ?? '';
    String truckType = json['truckType']?.toString() ?? '';
    if (truckType.isNotEmpty) {
      // Format: dry_van → Dry Van
      status = truckType
          .split('_')
          .map((w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1)}'
              : '')
          .join(' ');
    }

    // Requirements from specialRequirements + truckType
    final reqs = <String>[];
    if (truckType.isNotEmpty) {
      reqs.add(truckType
          .split('_')
          .map((w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1)}'
              : '')
          .join(' '));
    }
    if (json['specialRequirements'] != null &&
        json['specialRequirements'].toString().isNotEmpty) {
      reqs.add(json['specialRequirements'].toString());
    }
    if (json['requirements'] is List) {
      reqs.addAll(List<String>.from(json['requirements']));
    }

    // Load number
    String loadNumber = json['loadNumber']?.toString() ?? '';
    if (loadNumber.isEmpty) {
      final idStr = json['_id']?.toString() ?? json['id']?.toString() ?? '';
      if (idStr.length >= 6) {
        loadNumber = '#FL-${idStr.substring(idStr.length - 6).toUpperCase()}';
      } else {
        loadNumber = '#FL-$idStr';
      }
    }

    return Load(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      loadNumber: loadNumber,
      rate: rate,
      rateUnit: rateUnit,
      commodity: json['commodity']?.toString() ?? 'General Freight',
      origin: originCity,
      originState: originState,
      originDate: originDate,
      originTime: originTime,
      destination: destCity,
      destinationState: destState,
      destinationDate: destDate,
      destinationTime: destTime,
      weight: weight,
      distance: distance,
      status: status,
      requirements: reqs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loadNumber': loadNumber,
      'rate': rate,
      'rateUnit': rateUnit,
      'commodity': commodity,
      'origin': origin,
      'originState': originState,
      'originDate': originDate,
      'originTime': originTime,
      'destination': destination,
      'destinationState': destinationState,
      'destinationDate': destinationDate,
      'destinationTime': destinationTime,
      'weight': weight,
      'distance': distance,
      'status': status,
      'requirements': requirements,
    };
  }
}
