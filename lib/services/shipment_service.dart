import 'package:flutter/foundation.dart';
import '../models/shipment.dart';
import 'api_client.dart';

class ShipmentService {
  static final ShipmentService _instance = ShipmentService._internal();

  final ApiClient _api = ApiClient();

  factory ShipmentService() {
    return _instance;
  }

  ShipmentService._internal();

  /// Get active shipments (booked + in_transit loads) for current user.
  /// The backend /api/loads endpoint is org-scoped and returns paginated results.
  Future<List<Shipment>> getCurrentUserShipments() async {
    try {
      final data = await _api.get('/loads', query: {
        'status': 'booked',
      });
      final bookedShipments = _parseLoadsResponse(data);

      // Also get in_transit
      final data2 = await _api.get('/loads', query: {
        'status': 'in_transit',
      });
      final inTransitShipments = _parseLoadsResponse(data2);

      return [...bookedShipments, ...inTransitShipments];
    } catch (e) {
      debugPrint('Error fetching shipments: $e');
      return [];
    }
  }

  /// Parse the backend response which is { loads: [...], meta: {...} } or a plain array.
  List<Shipment> _parseLoadsResponse(dynamic data) {
    if (data != null && data is Map<String, dynamic>) {
      final loads = data['loads'] as List?;
      if (loads != null) {
        return loads
            .map((e) => Shipment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    if (data != null && data is List) {
      return data
          .map((e) => Shipment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Add a shipment – now a no-op since booking creates the association
  /// server-side. Kept for backward compatibility with the booking flow.
  Future<bool> addShipment({
    required String loadId,
    required String commodity,
    required String origin,
    required String destination,
    required String originDate,
    required String destinationDate,
    required String weight,
    required String rate,
  }) async {
    // Server handles shipment creation when a load is booked.
    return true;
  }

  /// Get shipment by ID.
  Future<Shipment?> getShipmentById(String shipmentId) async {
    try {
      final data = await _api.get('/loads/$shipmentId');
      if (data != null && data is Map<String, dynamic>) {
        return Shipment.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching shipment: $e');
      return null;
    }
  }

  /// Update shipment status.
  Future<bool> updateShipmentStatus(String shipmentId, String status) async {
    try {
      // Map UI status to backend status
      String backendStatus = status.toLowerCase();
      switch (status.toLowerCase()) {
        case 'active':
          backendStatus = 'booked';
          break;
        case 'in transit':
          backendStatus = 'in_transit';
          break;
        case 'delivered':
          backendStatus = 'delivered';
          break;
        case 'completed':
          backendStatus = 'completed';
          break;
        case 'cancelled':
          backendStatus = 'cancelled';
          break;
      }

      await _api.patch('/loads/$shipmentId/status', body: {
        'status': backendStatus,
      });
      return true;
    } catch (e) {
      debugPrint('Error updating shipment status: $e');
      return false;
    }
  }

  /// Delete/cancel a shipment.
  Future<bool> deleteShipment(String shipmentId) async {
    try {
      // Use the status transition to set cancelled
      await _api.patch('/loads/$shipmentId/status', body: {
        'status': 'cancelled',
      });
      return true;
    } catch (e) {
      debugPrint('Error deleting shipment: $e');
      return false;
    }
  }

  /// Complete a shipment (mark as delivered).
  Future<bool> completeShipment(String shipmentId) async {
    return updateShipmentStatus(shipmentId, 'delivered');
  }

  /// Get completed/delivered shipments.
  Future<List<Shipment>> getCompletedShipments() async {
    try {
      final data = await _api.get('/loads', query: {
        'status': 'delivered',
      });
      final deliveredShipments = _parseLoadsResponse(data);

      // Also get completed
      final data2 = await _api.get('/loads', query: {
        'status': 'completed',
      });
      final completedShipments = _parseLoadsResponse(data2);

      final all = [...deliveredShipments, ...completedShipments];
      return all.reversed.toList();
    } catch (e) {
      debugPrint('Error fetching completed shipments: $e');
      return [];
    }
  }
}
