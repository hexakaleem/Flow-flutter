import '../models/load.dart';

class LoadService {
  static final LoadService _instance = LoadService._internal();

  late List<Load> _availableLoads;

  factory LoadService() {
    return _instance;
  }

  LoadService._internal() {
    _initializeDummyLoads();
  }

  void _initializeDummyLoads() {
    _availableLoads = [
      Load(
        id: '1',
        loadNumber: '#FL-8812',
        rate: '\$2,800',
        rateUnit: '\$3,550/mi',
        commodity: 'Fresh Food',
        origin: 'Dallas',
        originState: 'TX, USA',
        originDate: 'Apr 3',
        originTime: '08:00',
        destination: 'Atlanta',
        destinationState: 'GA, USA',
        destinationDate: 'Apr 4',
        destinationTime: '18:00',
        weight: '48,000 lbs',
        distance: '74 mi',
        status: 'In transit',
        requirements: ['Reefer', 'Full TL'],
      ),
      Load(
        id: '2',
        loadNumber: '#FL-7209',
        rate: '\$1,950',
        rateUnit: '\$2,140/mi',
        commodity: 'Automotive Parts',
        origin: 'Houston',
        originState: 'TX, USA',
        originDate: 'Apr 3',
        originTime: '10:00',
        destination: 'Miami',
        destinationState: 'FL, USA',
        destinationDate: 'Apr 5',
        destinationTime: '14:00',
        weight: '44,000 lbs',
        distance: '74 mi',
        status: 'Dry Van',
        requirements: ['Dry Van', 'Full TL'],
      ),
      Load(
        id: '3',
        loadNumber: '#FL-83417',
        rate: '\$3,400',
        rateUnit: '\$4,200/mi',
        commodity: 'Consumer Electronics',
        origin: 'Chicago',
        originState: 'IL, USA',
        originDate: 'Apr 4',
        originTime: '06:00',
        destination: 'Charlotte',
        destinationState: 'NC, USA',
        destinationDate: 'Apr 6',
        destinationTime: '16:00',
        weight: '38,500 lbs',
        distance: '65 mi',
        status: '18PC',
        requirements: ['Reefer', 'Full TL'],
      ),
      Load(
        id: '4',
        loadNumber: '#FL-51830',
        rate: '\$890',
        rateUnit: '\$1,200/mi',
        commodity: 'General Freight',
        origin: 'Nashville',
        originState: 'TN, USA',
        originDate: 'Apr 3',
        originTime: '14:00',
        destination: 'Louisville',
        destinationState: 'KY, USA',
        destinationDate: 'Apr 3',
        destinationTime: '20:00',
        weight: '12,000 lbs',
        distance: '88 mi',
        status: 'Dry Van',
        requirements: ['Dry Van', 'LTL'],
      ),
      Load(
        id: '5',
        loadNumber: '#FL-9204',
        rate: '\$2,150',
        rateUnit: '\$2,890/mi',
        commodity: 'Perishable Goods',
        origin: 'Phoenix',
        originState: 'AZ, USA',
        originDate: 'Apr 4',
        originTime: '12:00',
        destination: 'Denver',
        destinationState: 'CO, USA',
        destinationDate: 'Apr 5',
        destinationTime: '10:00',
        weight: '40,000 lbs',
        distance: '68 mi',
        status: 'Reefer',
        requirements: ['Reefer', 'Full TL', 'Hazmat'],
      ),
      Load(
        id: '6',
        loadNumber: '#FL-7651',
        rate: '\$1,750',
        rateUnit: '\$2,100/mi',
        commodity: 'Industrial Equipment',
        origin: 'Cleveland',
        originState: 'OH, USA',
        originDate: 'Apr 5',
        originTime: '09:00',
        destination: 'Pittsburgh',
        destinationState: 'PA, USA',
        destinationDate: 'Apr 5',
        destinationTime: '19:00',
        weight: '52,000 lbs',
        distance: '80 mi',
        status: 'Flatbed',
        requirements: ['Flatbed', 'Full TL'],
      ),
    ];
  }

  // Get all available loads
  Future<List<Load>> getAvailableLoads() async {
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));
      return _availableLoads;
    } catch (e) {
      print('Error fetching loads: $e');
      return [];
    }
  }

  // Get load by ID
  Future<Load?> getLoadById(String loadId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final load = _availableLoads.firstWhere(
        (load) => load.id == loadId,
        orElse: () => Load(
          id: '',
          loadNumber: '',
          rate: '',
          rateUnit: '',
          commodity: '',
          origin: '',
          originState: '',
          originDate: '',
          originTime: '',
          destination: '',
          destinationState: '',
          destinationDate: '',
          destinationTime: '',
          weight: '',
          distance: '',
          status: '',
          requirements: [],
        ),
      );

      if (load.id.isEmpty) return null;
      return load;
    } catch (e) {
      print('Error fetching load: $e');
      return null;
    }
  }

  // Book a load (remove from available)
  Future<bool> bookLoad(String loadId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      _availableLoads.removeWhere((load) => load.id == loadId);
      return true;
    } catch (e) {
      print('Error booking load: $e');
      return false;
    }
  }

  // Search loads by origin and destination
  Future<List<Load>> searchLoads({
    required String origin,
    required String destination,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      return _availableLoads
          .where((load) =>
              load.origin.toLowerCase().contains(origin.toLowerCase()) &&
              load.destination
                  .toLowerCase()
                  .contains(destination.toLowerCase()))
          .toList();
    } catch (e) {
      print('Error searching loads: $e');
      return [];
    }
  }

  // Filter loads by rate range
  Future<List<Load>> filterLoadsByRate({
    required double minRate,
    required double maxRate,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      return _availableLoads.where((load) {
        final rateValue =
            double.parse(load.rate.replaceAll('\$', '').replaceAll(',', ''));
        return rateValue >= minRate && rateValue <= maxRate;
      }).toList();
    } catch (e) {
      print('Error filtering loads: $e');
      return [];
    }
  }
}
