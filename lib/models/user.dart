class User {
  final String id;
  final String email;
  final String role;
  final String firstName;
  final String lastName;
  final String phone;
  final String companyName;
  final bool isOnboardingComplete;
  final bool identityVerified;

  // Legacy convenience getters
  String get username => '$firstName $lastName'.trim().isEmpty
      ? email.split('@').first
      : '$firstName $lastName'.trim();
  String get mcNumber => id; // backward compat for existing code
  String get phoneNumber => phone;
  String get truckNumber => '';
  String get password => ''; // never stored locally

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.phone = '',
    this.companyName = '',
    this.isOnboardingComplete = false,
    this.identityVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'independent_driver',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'] ?? '',
      companyName: json['companyName'] ?? '',
      isOnboardingComplete: json['isOnboardingComplete'] == true,
      identityVerified: json['identityVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'companyName': companyName,
      'isOnboardingComplete': isOnboardingComplete,
      'identityVerified': identityVerified,
    };
  }
}
