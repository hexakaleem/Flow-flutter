import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _mcController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB066FE),
              Color(0xFF6A1B9A),
              Colors.black,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Column(
              children: [
                const SizedBox(height: 55),
                Image.asset(
                  'assets/logo.png',
                  height: 80,
                  color: Colors.black,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(height: 10),
                Text(
                  'FLOW',
                  style: GoogleFonts.montserratAlternates(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Driver App',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black54,
                          blurRadius: 20,
                          offset: Offset(0, -10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'REGISTER',
                          style: GoogleFonts.montserratAlternates(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Username',
                          style: GoogleFonts.poppins(color: Colors.white70)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Enter username...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Text('MC number',
                          style: GoogleFonts.poppins(color: Colors.white70)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _mcController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Enter mc number...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Text('Password',
                          style: GoogleFonts.poppins(color: Colors.white70)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Enter password...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      if (_error.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (_error.isNotEmpty) const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 10,
                          shadowColor: AppTheme.primaryPurple.withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                'Register',
                                style: GoogleFonts.poppins(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                  context, '/login'),
                          child: Text(
                            'Already have an account? Login',
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    setState(() {
      _error = '';
      _isLoading = true;
    });

    final username = _usernameController.text.trim();
    final mc = _mcController.text.trim();
    final pwd = _passwordController.text.trim();

    if (username.isEmpty || mc.isEmpty || pwd.isEmpty) {
      setState(() {
        _error = 'Please fill all fields';
        _isLoading = false;
      });
      return;
    }

    if (pwd.length < 8) {
      setState(() {
        _error = 'Password must be at least 8 characters';
        _isLoading = false;
      });
      return;
    }

    final registered = await _authService.register(
      username: username,
      mcNumber: mc,
      password: pwd,
      email: '',
      phoneNumber: '',
      truckNumber: '',
      companyName: '',
    );
    if (registered) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() {
        _error = 'MC number already registered';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _mcController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
