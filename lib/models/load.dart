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

  factory Load.fromJson(Map<String, dynamic> json) {
    return Load(
      id: json['id'],
      loadNumber: json['loadNumber'],
      rate: json['rate'],
      rateUnit: json['rateUnit'],
      commodity: json['commodity'],
      origin: json['origin'],
      originState: json['originState'],
      originDate: json['originDate'],
      originTime: json['originTime'],
      destination: json['destination'],
      destinationState: json['destinationState'],
      destinationDate: json['destinationDate'],
      destinationTime: json['destinationTime'],
      weight: json['weight'],
      distance: json['distance'],
      status: json['status'],
      requirements: List<String>.from(json['requirements'] ?? []),
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
