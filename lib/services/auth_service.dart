import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  User? _currentUser;
  final List<User> _registeredUsers = [];

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  User? get currentUser => _currentUser;

  bool isLoggedIn() {
    return _currentUser != null;
  }

  // Register a new user with dummy data
  Future<bool> register({
    required String username,
    required String mcNumber,
    required String password,
    required String email,
    required String phoneNumber,
    required String truckNumber,
    required String companyName,
  }) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(seconds: 1));

      // Check if user already exists
      if (_registeredUsers.any((user) => user.mcNumber == mcNumber)) {
        return false;
      }

      // Create and store user
      final newUser = User(
        username: username,
        mcNumber: mcNumber,
        password: password,
        email: email,
        phoneNumber: phoneNumber,
        truckNumber: truckNumber,
        companyName: companyName,
      );

      _registeredUsers.add(newUser);
      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  // Login with dummy data validation
  Future<bool> login({
    required String mcNumber,
    required String password,
  }) async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(seconds: 1));

      // Find user by MC number
      final user = _registeredUsers.firstWhere(
        (user) => user.mcNumber == mcNumber && user.password == password,
        orElse: () => User(
          username: '',
          mcNumber: '',
          password: '',
          email: '',
          phoneNumber: '',
          truckNumber: '',
          companyName: '',
        ),
      );

      if (user.username.isEmpty) {
        // Try dummy credentials
        if (mcNumber == 'MC123456' && password == 'password123') {
          _currentUser = User(
            username: 'Salar',
            mcNumber: 'MC123456',
            password: 'password123',
            email: '',
            phoneNumber: '',
            truckNumber: '',
            companyName: '',
          );
          return true;
        }
        return false;
      }

      _currentUser = user;
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Logout
  void logout() {
    _currentUser = null;
  }

  // Get all registered users (for debugging)
  List<User> getAllUsers() {
    return _registeredUsers;
  }
}
