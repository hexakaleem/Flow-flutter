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

  factory Shipment.fromJson(Map<String, dynamic> json) {
    return Shipment(
      id: json['id'],
      loadId: json['loadId'],
      commodity: json['commodity'],
      origin: json['origin'],
      destination: json['destination'],
      originDate: json['originDate'],
      destinationDate: json['destinationDate'],
      weight: json['weight'],
      rate: json['rate'],
      status: json['status'],
      carrier: json['carrier'],
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
