import 'driver.dart';

class Ride {
  final String id;
  final String userId;
  final String? driverId;
  final String vehicleType;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropLat;
  final double dropLng;
  final String dropAddress;
  final int fareEstimate;
  String status;
  Driver? driver;

  Ride({
    required this.id,
    required this.userId,
    this.driverId,
    required this.vehicleType,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropLat,
    required this.dropLng,
    required this.dropAddress,
    required this.fareEstimate,
    required this.status,
    this.driver,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      driverId: json['driver_id'],
      vehicleType: json['vehicle_type'] ?? json['vehicleType'] ?? '',
      pickupLat: (json['pickup_lat'] ?? json['pickupLat'] ?? 0).toDouble(),
      pickupLng: (json['pickup_lng'] ?? json['pickupLng'] ?? 0).toDouble(),
      pickupAddress: json['pickup_address'] ?? json['pickupAddress'] ?? '',
      dropLat: (json['drop_lat'] ?? json['dropLat'] ?? 0).toDouble(),
      dropLng: (json['drop_lng'] ?? json['dropLng'] ?? 0).toDouble(),
      dropAddress: json['drop_address'] ?? json['dropAddress'] ?? '',
      fareEstimate: json['fare_estimate'] ?? json['fareEstimate'] ?? 0,
      status: json['status'] ?? 'requested',
      driver: json['driver'] != null ? Driver.fromJson(json['driver']) : null,
    );
  }
}
