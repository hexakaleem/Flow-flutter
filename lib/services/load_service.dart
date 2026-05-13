import 'package:flutter/foundation.dart';
import '../models/load.dart';
import 'api_client.dart';
import 'auth_service.dart';

class LoadService {
  static final LoadService _instance = LoadService._internal();

  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();

  factory LoadService() {
    return _instance;
  }

  LoadService._internal();

  /// Get all available loads from the marketplace.
  Future<List<Load>> getAvailableLoads() async {
    try {
      final data = await _api.get('/marketplace/loads');
      if (data != null && data is Map<String, dynamic>) {
        // Backend returns { loads: [...], meta: {...} }
        final loads = data['loads'] as List?;
        if (loads != null) {
          return loads
              .map((e) => Load.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      // Fallback: if data is a plain array
      if (data != null && data is List) {
        return data
            .map((e) => Load.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('Error fetching marketplace loads: $e');
      return [];
    } catch (e) {
      debugPrint('Error fetching loads: $e');
      return [];
    }
  }

  /// Get load by ID.
  Future<Load?> getLoadById(String loadId) async {
    try {
      final data = await _api.get('/loads/$loadId');
      if (data != null && data is Map<String, dynamic>) {
        return Load.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching load: $e');
      return null;
    }
  }

  /// Book a load by creating a booking request.
  /// The backend requires truckId in the body.
  Future<bool> bookLoad(String loadId) async {
    try {
      final truckId = _auth.truckId;
      if (truckId == null || truckId.isEmpty) {
        throw ApiException(
          message: 'Please register a vehicle before booking loads',
          code: 'NO_TRUCK',
          statusCode: 400,
        );
      }

      final userId = _auth.currentUser?.id ?? '';

      await _api.post('/loads/$loadId/booking-request', body: {
        'truckId': truckId,
        'driverId': userId,
      });
      return true;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('Error booking load: $e');
      return false;
    }
  }

  /// Search loads by origin and destination.
  Future<List<Load>> searchLoads({
    required String origin,
    required String destination,
  }) async {
    try {
      final query = <String, String>{};
      if (origin.isNotEmpty) query['originCity'] = origin;
      if (destination.isNotEmpty) query['destCity'] = destination;

      final data = await _api.get('/marketplace/loads', query: query);
      if (data != null && data is Map<String, dynamic>) {
        final loads = data['loads'] as List?;
        if (loads != null) {
          return loads
              .map((e) => Load.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      if (data != null && data is List) {
        return data
            .map((e) => Load.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching loads: $e');
      return [];
    }
  }

  /// Filter loads by rate range.
  Future<List<Load>> filterLoadsByRate({
    required double minRate,
    required double maxRate,
  }) async {
    try {
      final data = await _api.get('/marketplace/loads', query: {
        'minRate': minRate.toString(),
        'maxRate': maxRate.toString(),
      });
      if (data != null && data is Map<String, dynamic>) {
        final loads = data['loads'] as List?;
        if (loads != null) {
          return loads
              .map((e) => Load.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      if (data != null && data is List) {
        return data
            .map((e) => Load.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error filtering loads: $e');
      return [];
    }
  }
}
