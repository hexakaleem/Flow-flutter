import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/vehicle_profile.dart';
import 'api_client.dart';
import 'token_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  User? _currentUser;
  VehicleProfile? _vehicleProfile;
  String? _truckId; // Cached truck ID from fleet API

  final ApiClient _api = ApiClient();
  final TokenService _tokens = TokenService();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  User? get currentUser => _currentUser;
  String? get truckId => _truckId;

  bool isLoggedIn() {
    return _currentUser != null;
  }

  // ── Persistence helpers (lightweight – just for session indicator) ──────────

  static const _kUserId = 'session_user_id';

  Future<void> _persistSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, user.id);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await _tokens.clearTokens();
  }

  /// Call this once at app startup (before runApp).
  /// Returns true if a saved session was restored.
  static Future<bool> tryAutoLogin() async {
    final instance = AuthService();
    await instance._tokens.load();

    if (!instance._tokens.hasTokens) return false;

    try {
      // Validate the token by fetching the current user profile.
      final data = await instance._api.get('/auth/me');
      if (data != null && data is Map<String, dynamic>) {
        instance._currentUser = User.fromJson(data);
        await instance._persistSession(instance._currentUser!);

        // Also try to load vehicle profile
        await instance._loadVehicleProfile();
        
        // Auto-complete onboarding steps if needed (in case they finished on web)
        await instance._completeOnboardingIfNeeded();

        return true;
      }
    } catch (e) {
      debugPrint('Auto-login failed: $e');
      // Token is invalid or expired beyond refresh – clear everything.
      await instance._clearSession();
    }
    return false;
  }

  // ── Auth methods ───────────────────────────────────────────────────────────

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String role = 'independent_driver',
    // Legacy params – kept for backward compat, ignored by backend
    String username = '',
    String mcNumber = '',
    String phoneNumber = '',
    String truckNumber = '',
    String companyName = '',
  }) async {
    try {
      await _api.post('/auth/register', body: {
        'email': email,
        'password': password,
        'role': role,
        'firstName': firstName.isNotEmpty ? firstName : username,
        'lastName': lastName,
      }, auth: false);
      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    // Legacy param – kept for backward compat
    String mcNumber = '',
  }) async {
    try {
      final data = await _api.post('/auth/login', body: {
        'email': email.isNotEmpty ? email : mcNumber,
        'password': password,
      }, auth: false);

      if (data != null && data is Map<String, dynamic>) {
        // Store tokens
        await _tokens.saveTokens(
          accessToken: data['accessToken'] ?? '',
          refreshToken: data['refreshToken'] ?? '',
        );

        // Parse user from the login response
        final userData = data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          _currentUser = User.fromJson(userData);
          await _persistSession(_currentUser!);

          // Auto-complete onboarding steps so gateway doesn't block access
          await _completeOnboardingIfNeeded();

          // Load vehicle profile after login
          await _loadVehicleProfile();

          return true;
        }
      }
      return false;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  /// Completes all onboarding steps for the driver if not already done.
  /// The backend gateway blocks non-onboarding routes when isOnboardingComplete=false.
  Future<void> _completeOnboardingIfNeeded() async {
    if (_currentUser == null) return;
    if (_currentUser!.isOnboardingComplete) return;

    try {
      // Complete profile step
      await _api.patch('/auth/onboarding/profile', body: {
        'firstName': _currentUser!.firstName.isNotEmpty ? _currentUser!.firstName : 'Driver',
        'lastName': _currentUser!.lastName.isNotEmpty ? _currentUser!.lastName : 'User',
      });
      // Complete business step
      await _api.patch('/auth/onboarding/business', body: {});
      // Complete stripe step (skip actual Stripe setup)
      await _api.patch('/auth/onboarding/stripe', body: {});
      // Complete preferences step — returns a new accessToken with updated claims
      final prefsData = await _api.patch('/auth/onboarding/prefs', body: {});
      if (prefsData != null && prefsData is Map<String, dynamic>) {
        final newToken = prefsData['accessToken'] as String?;
        if (newToken != null && newToken.isNotEmpty) {
          await _tokens.updateAccessToken(newToken);
        }
      }
      debugPrint('Onboarding auto-completed for ${_currentUser!.email}');

      // Refresh the user data (onboarding now complete)
      final meData = await _api.get('/auth/me');
      if (meData != null && meData is Map<String, dynamic>) {
        _currentUser = User.fromJson(meData);
      }
    } catch (e) {
      debugPrint('Onboarding auto-complete error: $e');
      // Non-fatal – user can still use onboarding-allowed routes
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Best effort – clear local state regardless.
    }
    _currentUser = null;
    _vehicleProfile = null;
    _truckId = null;
    await _clearSession();
  }

  // ── User profile ──────────────────────────────────────────────────────────

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? companyName,
  }) async {
    if (_currentUser == null) return false;
    try {
      final body = <String, dynamic>{};
      if (firstName != null) body['firstName'] = firstName;
      if (lastName != null) body['lastName'] = lastName;
      if (phone != null) body['phone'] = phone;
      if (companyName != null) body['companyName'] = companyName;

      await _api.patch('/users/${_currentUser!.id}', body: body);

      // Refresh user data
      final data = await _api.get('/auth/me');
      if (data != null && data is Map<String, dynamic>) {
        _currentUser = User.fromJson(data);
      }
      return true;
    } catch (e) {
      debugPrint('Profile update error: $e');
      return false;
    }
  }

  // ── Vehicle profile ────────────────────────────────────────────────────────

  Future<void> _loadVehicleProfile() async {
    try {
      final data = await _api.get('/fleet/trucks');
      // Backend returns { trucks: [...], meta: {...} }
      if (data != null && data is Map<String, dynamic>) {
        final trucks = data['trucks'] as List?;
        if (trucks != null && trucks.isNotEmpty) {
          final truck = trucks[0] as Map<String, dynamic>;
          _truckId = truck['_id']?.toString() ?? '';
          _vehicleProfile = _truckToVehicleProfile(truck);
          return;
        }
      }
      // Fallback: data is a plain array (shouldn't happen, but safe)
      if (data != null && data is List && data.isNotEmpty) {
        final truck = data[0] as Map<String, dynamic>;
        _truckId = truck['_id']?.toString() ?? '';
        _vehicleProfile = _truckToVehicleProfile(truck);
      }
    } catch (e) {
      debugPrint('Vehicle profile load error: $e');
    }
  }

  VehicleProfile? getVehicleProfile(String userId) {
    return _vehicleProfile;
  }

  bool hasVehicleProfile(String userId) {
    return _vehicleProfile != null;
  }

  Future<bool> saveVehicleProfile({
    required String userId,
    required VehicleProfile profile,
  }) async {
    try {
      // ── 1. Upload documents if file paths are provided ──────────────────
      String? registrationDocUrl;
      String? insuranceDocUrl;

      if (profile.registrationDocumentPath != null &&
          profile.registrationDocumentPath!.isNotEmpty) {
        registrationDocUrl = await _uploadDocument(
          filePath: profile.registrationDocumentPath!,
          type: 'registration',
        );
      }

      if (profile.insuranceDocumentPath != null &&
          profile.insuranceDocumentPath!.isNotEmpty) {
        insuranceDocUrl = await _uploadDocument(
          filePath: profile.insuranceDocumentPath!,
          type: 'insurance',
        );
      }

      // ── 2. Build truck body ────────────────────────────────────────────
      final truckType = _mapEquipmentType(profile.equipmentType);

      final body = <String, dynamic>{
        'plateNumber': profile.licensePlate,
        'plateState': profile.state.isNotEmpty ? profile.state : 'N/A',
        'internalId': profile.internalFleetId.isNotEmpty
            ? profile.internalFleetId
            : 'TRK-${DateTime.now().millisecondsSinceEpoch}',
        'type': truckType,
        'vin': profile.vinNumber.isNotEmpty ? profile.vinNumber : null,
        'year': int.tryParse(profile.year) ?? 0,
        'make': profile.make,
        'vehicleModel': profile.model,
        'specs': {
          'maxWeight': int.tryParse(profile.maxWeight.replaceAll(',', '')) ?? 0,
          'length': int.tryParse(profile.trailerLength) ?? 0,
          'width': int.tryParse(profile.trailerWidth) ?? 0,
          'height': int.tryParse(profile.trailerHeight) ?? 0,
          'hasLiftgate': profile.hasLiftgate,
          'isHazmatCertified': profile.isHazmatCertified,
        },
      };

      // Attach document info to the truck record if uploads succeeded
      if (registrationDocUrl != null) {
        body['registrationNumber'] = profile.registrationDocumentLabel.isNotEmpty
            ? profile.registrationDocumentLabel
            : 'Registration';
        // Store the URL in photos so it's persisted on the truck
        body['photos'] = [
          if (registrationDocUrl.isNotEmpty) registrationDocUrl,
          if (insuranceDocUrl != null && insuranceDocUrl.isNotEmpty)
            insuranceDocUrl,
        ];
      }

      if (insuranceDocUrl != null) {
        body['insurancePolicy'] = profile.insuranceDocumentLabel.isNotEmpty
            ? profile.insuranceDocumentLabel
            : 'Insurance';
      }

      // ── 3. Create or update truck ──────────────────────────────────────
      if (_truckId != null && _truckId!.isNotEmpty) {
        // Update existing truck
        await _api.patch('/fleet/trucks/$_truckId', body: body);
      } else {
        // Create new truck
        final result = await _api.post('/fleet/trucks', body: body);
        if (result != null && result is Map<String, dynamic>) {
          _truckId = result['_id']?.toString() ?? '';
        }
      }

      // Reload vehicle profile
      await _loadVehicleProfile();
      return true;
    } on ApiException catch (e) {
      debugPrint('Vehicle profile save error: $e');
      rethrow;
    } catch (e) {
      debugPrint('Vehicle profile save error: $e');
      return false;
    }
  }

  /// Upload a document file (registration, insurance, etc.) to the backend.
  /// Returns the URL of the uploaded file, or null on failure.
  Future<String?> _uploadDocument({
    required String filePath,
    required String type,
  }) async {
    try {
      final data = await _api.uploadFile(
        '/documents/upload',
        filePath: filePath,
        fields: {'type': type},
      );

      if (data != null && data is Map<String, dynamic>) {
        return data['fileUrl']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('Document upload error ($type): $e');
      // Non-fatal — truck can still be created without docs
      return null;
    }
  }

  VehicleProfile _truckToVehicleProfile(Map<String, dynamic> truck) {
    final specs = truck['specs'] as Map<String, dynamic>? ?? {};
    return VehicleProfile(
      equipmentType: _reverseMapTruckType(truck['type']?.toString() ?? ''),
      licensePlate: truck['plateNumber']?.toString() ?? '',
      state: truck['plateState']?.toString() ?? '',
      vinNumber: truck['vin']?.toString() ?? '',
      year: truck['year']?.toString() ?? '',
      make: truck['make']?.toString() ?? '',
      model: truck['vehicleModel']?.toString() ?? '',
      trailerLength: specs['length']?.toString() ?? '',
      trailerWidth: specs['width']?.toString() ?? '',
      trailerHeight: specs['height']?.toString() ?? '',
      maxWeight: specs['maxWeight']?.toString() ?? '',
      internalFleetId: truck['internalId']?.toString() ?? '',
      registrationDocumentLabel: truck['registrationNumber']?.toString() ?? '',
      registrationDocumentType: 'PDF',
      insuranceDocumentLabel: truck['insurancePolicy']?.toString() ?? '',
      insuranceDocumentType: 'PDF',
    );
  }

  String _mapEquipmentType(String equipment) {
    final map = {
      'Dry Van': 'dry_van',
      'Flatbed': 'flatbed',
      'Reefer': 'reefer',
      'Step Deck': 'step_deck',
      'Lowboy': 'lowboy',
      'Tanker': 'tanker',
      'Power Only': 'power_only',
      'Sprinter Van': 'sprinter_van',
      'Box Truck': 'box_truck',
      'Hot Shot': 'hot_shot',
      'Heavy Haul': 'heavy_haul',
      'Conestoga': 'conestoga',
    };
    return map[equipment] ?? equipment.toLowerCase().replaceAll(' ', '_');
  }

  String _reverseMapTruckType(String type) {
    return type
        .split('_')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  List<User> getAllUsers() {
    // No longer meaningful with backend auth – return current user only.
    if (_currentUser != null) return [_currentUser!];
    return [];
  }
}
