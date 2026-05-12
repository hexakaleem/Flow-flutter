import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/fuel_log.dart';
import '../services/fuel_service.dart';
import '../services/receipt_ocr_parser.dart';

class FuelLogScreen extends StatefulWidget {
  const FuelLogScreen({super.key});

  @override
  State<FuelLogScreen> createState() => _FuelLogScreenState();
}

class _FuelLogScreenState extends State<FuelLogScreen> {
  final FuelService _fuelService = FuelService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _expenseController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  List<FuelLog> _logs = [];
  bool _loading = true;
  bool _saving = false;
  bool _gettingLocation = false;
  bool _scanningReceipt = false;
  DateTime _selectedDate = DateTime.now();
  double? _currentLatitude;
  double? _currentLongitude;
  File? _receiptImage;
  ParsedReceipt? _parsedReceipt;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final logs = await _fuelService.getFuelLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _gettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _gettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _gettingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Reverse geocode to get readable address
      String locationName =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      try {
        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse'
            '?lat=${position.latitude}&lon=${position.longitude}&format=json');
        final response =
            await http.get(url, headers: {'User-Agent': 'FlowDriverApp/1.0'});

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>? ?? {};
          final suburb =
              addr['suburb'] ?? addr['neighbourhood'] ?? addr['village'] ?? '';
          final city = addr['city'] ?? addr['town'] ?? addr['county'] ?? '';
          final parts =
              [suburb, city].where((s) => (s as String).isNotEmpty).toList();
          if (parts.isNotEmpty) {
            locationName = parts.take(2).join(', ');
          }
        }
      } catch (e) {
        // If reverse geocoding fails, keep coordinates as fallback
      }

      if (mounted) {
        setState(() {
          _currentLatitude = position.latitude;
          _currentLongitude = position.longitude;
          _locationController.text = locationName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _receiptImage = File(picked.path);
      _scanningReceipt = true;
      _parsedReceipt = null;
    });

    try {
      final parsed = await ReceiptOcrParser.parse(_receiptImage!);
      if (!mounted) return;
      setState(() {
        _parsedReceipt = parsed;
        _scanningReceipt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanningReceipt = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $e')),
      );
    }
  }

  void _applyParsedValues() {
    if (_parsedReceipt == null) return;
    if (_parsedReceipt!.expense != null) {
      _expenseController.text = _parsedReceipt!.expense!.toStringAsFixed(2);
    }
    if (_parsedReceipt!.quantity != null) {
      _quantityController.text = _parsedReceipt!.quantity!.toStringAsFixed(1);
    }
    setState(() {
      _receiptImage = null;
      _parsedReceipt = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt values applied to the form.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearReceipt() {
    setState(() {
      _receiptImage = null;
      _parsedReceipt = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8E5AF7),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveFuelLog() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final log = FuelLog(
      id: 'FL-${DateTime.now().millisecondsSinceEpoch}',
      expense: double.parse(_expenseController.text.trim()),
      quantity: double.parse(_quantityController.text.trim()),
      location: _locationController.text.trim(),
      latitude: _currentLatitude,
      longitude: _currentLongitude,
      date: _selectedDate,
      receiptImagePath: _receiptImage?.path,
    );

    final success = await _fuelService.addFuelLog(log);

    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      _expenseController.clear();
      _quantityController.clear();
      _locationController.clear();
      setState(() {
        _currentLatitude = null;
        _currentLongitude = null;
        _selectedDate = DateTime.now();
        _receiptImage = null;
        _parsedReceipt = null;
      });
      await _loadLogs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fuel log saved successfully!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Future<void> _deleteLog(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Fuel Log?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this fuel log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _fuelService.deleteFuelLog(id);
      if (!mounted) return;
      if (success) {
        await _loadLogs();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fuel log deleted.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    }
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF7F6FB),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8E5AF7), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFCE9FFC), Color(0xFFF8F9FA)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1128),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Text(
                            'Fuel Log',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFE8E1FF)),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8E5AF7)
                                            .withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.local_gas_station,
                                          color: Color(0xFF7A3FF2)),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Log Fuel Refill',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'Record your fuel expenses and location.',
                                            style: TextStyle(
                                                color: Colors.black54,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _buildField(
                                  'Expense (PKR/USD)',
                                  _expenseController,
                                  hint: 'e.g. 150.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    if (double.tryParse(value.trim()) == null) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildField(
                                  'Quantity (Liters/Gallons)',
                                  _quantityController,
                                  hint: 'e.g. 15.20',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    if (double.tryParse(value.trim()) == null) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildField(
                                  'Location',
                                  _locationController,
                                  hint: 'Enter location or use current',
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                  suffix: _gettingLocation
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF8E5AF7),
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.my_location,
                                              color: Color(0xFF8E5AF7)),
                                          onPressed: _getCurrentLocation,
                                          tooltip: 'Use current location',
                                        ),
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: _pickDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F6FB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 18, color: Color(0xFF8E5AF7)),
                                        const SizedBox(width: 12),
                                        Text(
                                          dateFormat.format(_selectedDate),
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.chevron_right,
                                            size: 18, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                // ── Receipt upload section ─────────────
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F6FB),
                                    borderRadius: BorderRadius.circular(14),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.receipt_long_outlined,
                                            size: 18,
                                            color: Color(0xFF7A3FF2),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Paid by card? Upload receipt',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (_receiptImage == null) ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _ReceiptSourceButton(
                                                icon: Icons.camera_alt_outlined,
                                                label: 'Camera',
                                                onTap: () => _pickReceiptImage(
                                                    ImageSource.camera),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _ReceiptSourceButton(
                                                icon: Icons.photo_outlined,
                                                label: 'Gallery',
                                                onTap: () => _pickReceiptImage(
                                                    ImageSource.gallery),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.file(
                                                _receiptImage!,
                                                width: 70,
                                                height: 70,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _scanningReceipt
                                                  ? const Row(
                                                      children: [
                                                        SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Color(
                                                                0xFF8E5AF7),
                                                          ),
                                                        ),
                                                        SizedBox(width: 10),
                                                        Text(
                                                          'Scanning receipt...',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color:
                                                                Colors.black54,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : _parsedReceipt != null
                                                      ? Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            if (_parsedReceipt!
                                                                    .expense !=
                                                                null)
                                                              Text(
                                                                'Expense: ${_parsedReceipt!.currency ?? 'PKR/USD'} ${_parsedReceipt!.expense!.toStringAsFixed(2)}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                              ),
                                                            if (_parsedReceipt!
                                                                    .quantity !=
                                                                null)
                                                              Text(
                                                                'Quantity: ${_parsedReceipt!.quantity!.toStringAsFixed(1)} ${_parsedReceipt!.unit ?? 'litres/gallons'}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                              ),
                                                            if (_parsedReceipt!
                                                                        .expense ==
                                                                    null &&
                                                                _parsedReceipt!
                                                                        .quantity ==
                                                                    null)
                                                              const Text(
                                                                'Could not read values. Type manually.',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .orange,
                                                                ),
                                                              ),
                                                          ],
                                                        )
                                                      : const SizedBox(),
                                            ),
                                            if (!_scanningReceipt &&
                                                _parsedReceipt != null &&
                                                (_parsedReceipt!.expense !=
                                                        null ||
                                                    _parsedReceipt!.quantity !=
                                                        null))
                                              TextButton(
                                                onPressed: _applyParsedValues,
                                                child: const Text('Apply'),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.close,
                                                  size: 18,
                                                  color: Colors.black54),
                                              onPressed: _clearReceipt,
                                              tooltip: 'Remove',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _saveFuelLog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8E5AF7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Save Fuel Log',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Fuel History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                  color: Colors.black),
                            ),
                          ),
                        if (!_loading && _logs.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.local_gas_station_outlined,
                                    size: 40, color: Colors.black38),
                                SizedBox(height: 8),
                                Text(
                                  'No fuel logs yet',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Add your first fuel refill above.',
                                  style: TextStyle(
                                    color: Colors.black38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!_loading && _logs.isNotEmpty)
                          ..._logs.map((log) => _buildFuelLogItem(log)),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelLogItem(FuelLog log) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8E5AF7).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_gas_station,
                color: Color(0xFF7A3FF2), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USD ${log.expense.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.quantity.toStringAsFixed(1)} gallons',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        log.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(log.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (log.receiptImagePath != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E5AF7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 14,
                  color: Color(0xFF7A3FF2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _deleteLog(log.id),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ReceiptOcrParser.dispose();
    _expenseController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}

class _ReceiptSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ReceiptSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF7A3FF2)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
