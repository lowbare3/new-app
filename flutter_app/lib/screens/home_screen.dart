import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../models/vehicle.dart';
import '../models/ride.dart';
import '../models/driver.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  final String phone;
  final String name;
  const HomeScreen({super.key, required this.userId, required this.phone, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SocketService _socket;
  final MapController _mapController = MapController();

  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  String _pickupAddress = '';
  String _dropAddress = '';

  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();

  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  bool _showVehicleSheet = false;
  bool _findingDriver = false;
  Ride? _currentRide;
  Driver? _assignedDriver;
  bool _rideActive = false;
  String _rideStatus = '';

  LatLng? _driverLatLng;
  Timer? _driverMoveTimer;
  Timer? _refreshTimer;

  final _pickupFocus = FocusNode();
  final _dropFocus = FocusNode();
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _dropSuggestions = [];
  bool _showPickupSuggestions = false;
  bool _showDropSuggestions = false;
  Timer? _debounce;

  static const _defaultCenter = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _socket = SocketService('http://10.0.2.2:3000');
    _socket.connect(widget.userId);
    _setupSocketListeners();
    _getCurrentLocation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_currentRide != null && !_rideActive) _checkRideStatus();
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    _debounce?.cancel();
    _refreshTimer?.cancel();
    _driverMoveTimer?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    _socket.on('ride_created', (data) {
      if (mounted) setState(() { _currentRide = Ride.fromJson(data); _findingDriver = true; });
    });
    _socket.on('ride_update', (data) {
      if (mounted) {
        setState(() {
          _currentRide = Ride.fromJson(data);
          if (data['driver'] != null) _assignedDriver = Driver.fromJson(data['driver']);
          _findingDriver = _currentRide!.status == 'finding_driver';
          _rideActive = _currentRide!.status == 'driver_assigned' || _currentRide!.status == 'driver_arrived' || _currentRide!.status == 'in_progress';
          _rideStatus = _currentRide!.status;
        });
      }
    });
    _socket.on('driver_location', (data) {
      if (mounted) {
        setState(() {
          _driverLatLng = LatLng(data['lat'], data['lng']);
        });
      }
    });
    _socket.on('ride_completed', (data) {
      if (mounted) {
        setState(() {
          _rideActive = false;
          _findingDriver = false;
          _currentRide = null;
          _assignedDriver = null;
          _driverLatLng = null;
          _rideStatus = '';
          _selectedVehicle = null;
          _showVehicleSheet = false;
        });
        _showReceipt(data);
      }
    });
  }

  void _showReceipt(dynamic data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Icon(Icons.check_circle, color: SheRideTheme.success, size: 64),
          const SizedBox(height: 16),
          const Text('Ride Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Thank you for riding with SheRide', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: SheRideTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Total Fare: ', style: TextStyle(fontSize: 18, color: SheRideTheme.textSecondary)),
              Text('₹${data['fare'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: SheRideTheme.primary)),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
        ]),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['lat'] != null && data['lon'] != null) {
          final loc = LatLng(data['lat'], data['lon']);
          setState(() {
            _pickupLatLng = loc;
            _pickupAddress = '${data['city'] ?? ''}, ${data['regionName'] ?? ''}';
            _pickupController.text = _pickupAddress;
          });
          _mapController.move(loc, 15);
          return;
        }
      }
    } catch (_) {}
    setState(() {
      _pickupLatLng = _defaultCenter;
      _pickupAddress = 'Current Location';
      _pickupController.text = _pickupAddress;
    });
  }

  void _onMapTap(TapPosition tap, LatLng point) {
    if (_pickupLatLng == null || (_dropLatLng == null && _pickupLatLng != null)) {
      setState(() {
        if (_pickupLatLng == null) {
          _pickupLatLng = point;
          _reverseGeocode(point, isPickup: true);
        } else if (_dropLatLng == null) {
          _dropLatLng = point;
          _reverseGeocode(point, isPickup: false);
          _fetchVehicles();
        }
      });
    }
  }

  Future<void> _reverseGeocode(LatLng point, {required bool isPickup}) async {
    try {
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final addr = data['display_name'] ?? '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        if (mounted) {
          setState(() {
            if (isPickup) { _pickupAddress = addr; _pickupController.text = addr; }
            else { _dropAddress = addr; _dropController.text = addr; }
          });
        }
      }
    } catch (_) {}
  }

  void _searchAddress(String query, {required bool isPickup}) async {
    if (query.length < 3) return;
    try {
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5'));
      if (res.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        if (mounted) {
          setState(() {
            if (isPickup) { _pickupSuggestions = data; _showPickupSuggestions = true; }
            else { _dropSuggestions = data; _showDropSuggestions = true; }
          });
        }
      }
    } catch (_) {}
  }

  void _selectSuggestion(Map<String, dynamic> item, {required bool isPickup}) {
    final lat = double.parse(item['lat']);
    final lon = double.parse(item['lon']);
    final point = LatLng(lat, lon);
    setState(() {
      if (isPickup) {
        _pickupLatLng = point;
        _pickupAddress = item['display_name'];
        _pickupController.text = item['display_name'];
        _showPickupSuggestions = false;
        _mapController.move(point, 15);
      } else {
        _dropLatLng = point;
        _dropAddress = item['display_name'];
        _dropController.text = item['display_name'];
        _showDropSuggestions = false;
        _fetchVehicles();
      }
    });
  }

  void _fetchVehicles() async {
    if (_pickupLatLng == null || _dropLatLng == null) return;
    final res = await ApiService.getVehicles(_pickupLatLng!.latitude, _pickupLatLng!.longitude, _dropLatLng!.latitude, _dropLatLng!.longitude);
    if (res['success'] && mounted) {
      setState(() {
        _vehicles = (res['vehicles'] as List).map((v) => Vehicle.fromJson(v)).toList();
        _selectedVehicle = _vehicles.isNotEmpty ? _vehicles[1] : null;
        _showVehicleSheet = true;
      });
    }
  }

  void _requestRide() async {
    if (_selectedVehicle == null || _pickupLatLng == null || _dropLatLng == null) return;
    setState(() => _findingDriver = true);
    final res = await ApiService.requestRide(
      userId: widget.userId,
      vehicleType: _selectedVehicle!.id,
      pickupLat: _pickupLatLng!.latitude,
      pickupLng: _pickupLatLng!.longitude,
      pickupAddress: _pickupAddress,
      dropLat: _dropLatLng!.latitude,
      dropLng: _dropLatLng!.longitude,
      dropAddress: _dropAddress,
    );
    if (res['success'] == false && mounted) {
      setState(() => _findingDriver = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error')));
    }
  }

  void _checkRideStatus() {
    if (_currentRide == null) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 14,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sheride.app',
              ),
              MarkerLayer(markers: _buildMarkers()),
              if (_rideActive && _pickupLatLng != null && _dropLatLng != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [_pickupLatLng!, _dropLatLng!],
                    color: SheRideTheme.primary.withOpacity(0.5),
                    strokeWidth: 3,
                  ),
                ]),
            ],
          ),
          Positioned(top: 40, left: 12, right: 12, child: _buildAddressPanel()),
          if (_showVehicleSheet && !_findingDriver && !_rideActive)
            Positioned(bottom: 0, left: 0, right: 0, child: _buildVehicleSheet()),
          if (_findingDriver) _buildFindingDriverOverlay(),
          if (_rideActive) Positioned(top: 100, left: 12, right: 12, child: _buildRideStatusCard()),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_pickupLatLng != null) {
      markers.add(Marker(
        point: _pickupLatLng!,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: SheRideTheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
      ));
    }
    if (_dropLatLng != null) {
      markers.add(Marker(
        point: _dropLatLng!,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: SheRideTheme.primaryDark, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 2)),
          child: const Text('🏁', style: TextStyle(fontSize: 16)),
        ),
      ));
    }
    if (_driverLatLng != null) {
      markers.add(Marker(
        point: _driverLatLng!,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
          child: const Center(child: Text('🚗', style: TextStyle(fontSize: 18))),
        ),
      ));
    }
    return markers;
  }

  Widget _buildAddressPanel() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Column(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: SheRideTheme.primary, shape: BoxShape.circle)),
              Container(width: 2, height: 20, color: Colors.grey[300]),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey[600]!, shape: BoxShape.circle)),
            ]),
            const SizedBox(width: 10),
            Expanded(child: Column(children: [
              _buildAddressField(_pickupController, _pickupFocus, 'Pickup location', true),
              const Divider(height: 4),
              _buildAddressField(_dropController, _dropFocus, 'Where to?', false),
            ])),
          ]),
        ]),
      ),
    );
  }

  Widget _buildAddressField(TextEditingController controller, FocusNode focusNode, String hint, bool isPickup) {
    return Stack(
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
          style: const TextStyle(fontSize: 14),
          onChanged: (val) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              if (val.length >= 3) _searchAddress(val, isPickup: isPickup);
            });
          },
        ),
        if ((isPickup && _showPickupSuggestions && _pickupSuggestions.isNotEmpty) ||
            (!isPickup && _showDropSuggestions && _dropSuggestions.isNotEmpty))
          Positioned(
            top: 40, left: 0, right: 0,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: (isPickup ? _pickupSuggestions : _dropSuggestions).length,
                  itemBuilder: (_, i) {
                    final item = (isPickup ? _pickupSuggestions : _dropSuggestions)[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on, size: 18, color: Colors.grey),
                      title: Text(item['display_name']?.toString().split(',').take(3).join(',') ?? '', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _selectSuggestion(item, isPickup: isPickup),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVehicleSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        ...List.generate(_vehicles.length, (i) {
          final v = _vehicles[i];
          final selected = _selectedVehicle?.id == v.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedVehicle = v),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? SheRideTheme.primaryLight : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? SheRideTheme.primary : Colors.grey[200]!, width: selected ? 2 : 1),
              ),
              child: Row(children: [
                Text(v.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: selected ? SheRideTheme.primary : Colors.black)),
                  Text('${v.description} · ${v.capacity} seats', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text('~${v.eta} away · ${v.distanceKm} km', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ])),
                Text('₹${v.fareEstimate}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: selected ? SheRideTheme.primary : Colors.black)),
              ]),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _requestRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: SheRideTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Request ${_selectedVehicle?.name ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildFindingDriverOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(strokeWidth: 4, color: SheRideTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text('Finding drivers near you...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Searching for available SheRide drivers', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 8),
            const Text('🔍', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() { _findingDriver = false; _showVehicleSheet = true; }),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRideStatusCard() {
    String statusText = '';
    Color statusColor = SheRideTheme.primary;
    switch (_rideStatus) {
      case 'driver_assigned': statusText = 'Driver on the way'; statusColor = Colors.purple; break;
      case 'driver_arrived': statusText = 'Driver has arrived!'; statusColor = SheRideTheme.warning; break;
      case 'in_progress': statusText = 'On your way!'; statusColor = SheRideTheme.success; break;
    }
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              child: Center(
                child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
            ),
            const SizedBox(width: 8),
            Text(statusText, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: statusColor)),
            const Spacer(),
            if (_assignedDriver != null) Text('⭐ ${_assignedDriver!.rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, color: Colors.amber)),
          ]),
          if (_assignedDriver != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: SheRideTheme.primaryLight,
                child: Text(_assignedDriver!.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: SheRideTheme.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_assignedDriver!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${_assignedDriver!.carModel} · ${_assignedDriver!.plate}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ])),
              Text('ETA: ${_rideStatus == 'driver_assigned' ? '2 min' : '0 min'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: SheRideTheme.primary)),
            ]),
          ],
        ]),
      ),
    );
  }
}
