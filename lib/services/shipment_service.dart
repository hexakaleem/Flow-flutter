import '../models/shipment.dart';
import 'auth_service.dart';

class ShipmentService {
  static final ShipmentService _instance = ShipmentService._internal();

  final Map<String, List<Shipment>> _userShipments = {};

  factory ShipmentService() {
    return _instance;
  }

  ShipmentService._internal();

  // Get shipments for current user
  Future<List<Shipment>> getCurrentUserShipments() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final currentUser = AuthService().currentUser;
      if (currentUser == null) return [];

      return _userShipments[currentUser.mcNumber] ?? [];
    } catch (e) {
      print('Error fetching shipments: $e');
      return [];
    }
  }

  // Add a new shipment (when load is booked)
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
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final currentUser = AuthService().currentUser;
      if (currentUser == null) return false;

      final userId = currentUser.mcNumber;
      if (!_userShipments.containsKey(userId)) {
        _userShipments[userId] = [];
      }

      final shipment = Shipment(
        id: 'SHIP-${DateTime.now().millisecondsSinceEpoch}',
        loadId: loadId,
        commodity: commodity,
        origin: origin,
        destination: destination,
        originDate: originDate,
        destinationDate: destinationDate,
        weight: weight,
        rate: rate,
        status: 'Active',
        carrier: currentUser.companyName,
      );

      _userShipments[userId]!.add(shipment);
      return true;
    } catch (e) {
      print('Error adding shipment: $e');
      return false;
    }
  }

  // Get shipment by ID
  Future<Shipment?> getShipmentById(String shipmentId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final currentUser = AuthService().currentUser;
      if (currentUser == null) return null;

      final shipments = _userShipments[currentUser.mcNumber] ?? [];
      return shipments.firstWhere(
        (shipment) => shipment.id == shipmentId,
        orElse: () => Shipment(
          id: '',
          loadId: '',
          commodity: '',
          origin: '',
          destination: '',
          originDate: '',
          destinationDate: '',
          weight: '',
          rate: '',
          status: '',
          carrier: '',
        ),
      );
    } catch (e) {
      print('Error fetching shipment: $e');
      return null;
    }
  }

  // Update shipment status
  Future<bool> updateShipmentStatus(String shipmentId, String status) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final currentUser = AuthService().currentUser;
      if (currentUser == null) return false;

      final shipments = _userShipments[currentUser.mcNumber] ?? [];
      final index = shipments.indexWhere((s) => s.id == shipmentId);

      if (index != -1) {
        // Create updated shipment with new status
        final oldShipment = shipments[index];
        shipments[index] = Shipment(
          id: oldShipment.id,
          loadId: oldShipment.loadId,
          commodity: oldShipment.commodity,
          origin: oldShipment.origin,
          destination: oldShipment.destination,
          originDate: oldShipment.originDate,
          destinationDate: oldShipment.destinationDate,
          weight: oldShipment.weight,
          rate: oldShipment.rate,
          status: status,
          carrier: oldShipment.carrier,
        );
        return true;
      }

      return false;
    } catch (e) {
      print('Error updating shipment status: $e');
      return false;
    }
  }

  // Delete shipment
  Future<bool> deleteShipment(String shipmentId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final currentUser = AuthService().currentUser;
      if (currentUser == null) return false;

      final shipments = _userShipments[currentUser.mcNumber] ?? [];
      shipments.removeWhere((s) => s.id == shipmentId);
      return true;
    } catch (e) {
      print('Error deleting shipment: $e');
      return false;
    }
  }
}
