import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

  static Future<Map<String, dynamic>> login(String phone, String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getVehicles(double pickupLat, double pickupLng, double dropLat, double dropLng) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/vehicles?pickupLat=$pickupLat&pickupLng=$pickupLng&dropLat=$dropLat&dropLng=$dropLng'),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> requestRide({
    required String userId,
    required String vehicleType,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropLat,
    required double dropLng,
    required String dropAddress,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/request-ride'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'vehicleType': vehicleType,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'pickupAddress': pickupAddress,
        'dropLat': dropLat,
        'dropLng': dropLng,
        'dropAddress': dropAddress,
      }),
    );
    return jsonDecode(res.body);
  }
}
