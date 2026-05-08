class User {
  final String username;
  final String mcNumber;
  final String password;
  final String email;
  final String phoneNumber;
  final String truckNumber;
  final String companyName;

  User({
    required this.username,
    required this.mcNumber,
    required this.password,
    required this.email,
    required this.phoneNumber,
    required this.truckNumber,
    required this.companyName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      mcNumber: json['mcNumber'],
      password: json['password'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      truckNumber: json['truckNumber'],
      companyName: json['companyName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'mcNumber': mcNumber,
      'password': password,
      'email': email,
      'phoneNumber': phoneNumber,
      'truckNumber': truckNumber,
      'companyName': companyName,
    };
  }
}
