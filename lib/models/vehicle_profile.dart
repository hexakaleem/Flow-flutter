class VehicleProfile {
  final String equipmentType;
  final String licensePlate;
  final String state;
  final String vinNumber;
  final String year;
  final String make;
  final String model;
  final String trailerLength;
  final String trailerWidth;
  final String trailerHeight;
  final String maxWeight;
  final String internalFleetId;
  final String registrationDocumentLabel;
  final String registrationDocumentType;
  final String insuranceDocumentLabel;
  final String insuranceDocumentType;
  final String? registrationDocumentPath;
  final String? insuranceDocumentPath;
  final bool hasLiftgate;
  final bool isHazmatCertified;

  const VehicleProfile({
    required this.equipmentType,
    required this.licensePlate,
    required this.state,
    required this.vinNumber,
    required this.year,
    required this.make,
    required this.model,
    required this.trailerLength,
    required this.trailerWidth,
    required this.trailerHeight,
    required this.maxWeight,
    required this.internalFleetId,
    required this.registrationDocumentLabel,
    required this.registrationDocumentType,
    required this.insuranceDocumentLabel,
    required this.insuranceDocumentType,
    this.registrationDocumentPath,
    this.insuranceDocumentPath,
    this.hasLiftgate = false,
    this.isHazmatCertified = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'equipmentType': equipmentType,
      'licensePlate': licensePlate,
      'state': state,
      'vinNumber': vinNumber,
      'year': year,
      'make': make,
      'model': model,
      'trailerLength': trailerLength,
      'trailerWidth': trailerWidth,
      'trailerHeight': trailerHeight,
      'maxWeight': maxWeight,
      'internalFleetId': internalFleetId,
      'registrationDocumentLabel': registrationDocumentLabel,
      'registrationDocumentType': registrationDocumentType,
      'insuranceDocumentLabel': insuranceDocumentLabel,
      'insuranceDocumentType': insuranceDocumentType,
      'registrationDocumentPath': registrationDocumentPath,
      'insuranceDocumentPath': insuranceDocumentPath,
      'hasLiftgate': hasLiftgate,
      'isHazmatCertified': isHazmatCertified,
    };
  }

  factory VehicleProfile.fromJson(Map<String, dynamic> json) {
    return VehicleProfile(
      equipmentType: json['equipmentType'] ?? '',
      licensePlate: json['licensePlate'] ?? '',
      state: json['state'] ?? '',
      vinNumber: json['vinNumber'] ?? '',
      year: json['year'] ?? '',
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      trailerLength: json['trailerLength'] ?? '',
      trailerWidth: json['trailerWidth'] ?? '',
      trailerHeight: json['trailerHeight'] ?? '',
      maxWeight: json['maxWeight'] ?? '',
      internalFleetId: json['internalFleetId'] ?? '',
      registrationDocumentLabel: json['registrationDocumentLabel'] ?? '',
      registrationDocumentType: json['registrationDocumentType'] ?? '',
      insuranceDocumentLabel: json['insuranceDocumentLabel'] ?? '',
      insuranceDocumentType: json['insuranceDocumentType'] ?? '',
      registrationDocumentPath: json['registrationDocumentPath'],
      insuranceDocumentPath: json['insuranceDocumentPath'],
      hasLiftgate: json['hasLiftgate'] ?? false,
      isHazmatCertified: json['isHazmatCertified'] ?? false,
    );
  }
}
